import Foundation

/// Cliente da nuvem MSmartHome: requisição assinada, login e relogin limitado.
/// Portado de `MideaCloud._api_request`, `MSmartHomeCloud._make_general_data`/`_api_request`/
/// `_re_route`/`login` e `MideaCloud._get_login_id`
/// (sususweet/midea_auto_cloud @ ce0c4b88224def0f6b53714312c19f71aa9c2a50,
/// custom_components/midea_auto_cloud/core/cloud.py, Apache-2.0).
public actor MideaCloudClient {
    /// Intervalo mínimo entre tentativas de login (sem relogin antes disso).
    private static let reloginCooldown: TimeInterval = 60

    private let account: String
    private let password: String
    private let transport: any HTTPTransport
    private let now: @Sendable () -> Date
    private let makeRequestId: @Sendable () -> String
    private let deviceId: String
    private let authorization: String

    private var apiURL = MideaConstants.baseURL
    private var accessToken: String?
    private var uid = ""
    private var lastLoginAttempt: Date?
    /// Login em andamento: chamadas concorrentes esperam por ele em vez de iniciar outro
    /// (o Python usa `_relogin_lock`; no actor, a reentrada nos `await` exigiria isto).
    private var loginTask: Task<Void, Error>?
    /// Chave e IV de sessão do último login (usados pelas Tasks de comando e estado).
    private(set) var sessionKeys: SessionKeys?

    public var isLoggedIn: Bool { accessToken != nil }

    public init(
        account: String, password: String, transport: any HTTPTransport,
        now: @escaping @Sendable () -> Date = Date.init,
        makeRequestId: @escaping @Sendable () -> String = MideaCloudClient.randomRequestId
    ) {
        self.account = account
        self.password = password
        self.transport = transport
        self.now = now
        self.makeRequestId = makeRequestId
        self.deviceId = MideaCrypto.deviceId(account: account)
        let basic = Data("\(MideaConstants.appKey):\(MideaConstants.iotKey)".utf8).base64EncodedString()
        self.authorization = "Basic \(basic)"
    }

    /// 32 caracteres hex aleatórios.
    @Sendable public static func randomRequestId() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<16).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }.joined()
    }

    // MARK: - Login

    /// Rota, id de login e login. Conta como tentativa para o limite de relogin.
    public func login() async throws {
        if let running = loginTask { return try await running.value }
        let task = Task { try await self.performLogin() }
        loginTask = task
        defer { loginTask = nil }
        try await task.value
    }

    private func performLogin() async throws {
        lastLoginAttempt = now()
        accessToken = nil
        try await reRoute()
        let loginId = try await fetchLoginId()

        var iotData = generalData()
        iotData.removeValue(forKey: "uid")
        let stamp = formattedStamp()
        iotData["iampwd"] = MideaCrypto.encryptIAMPassword(loginId: loginId, password: password)
        iotData["loginAccount"] = account
        iotData["password"] = MideaCrypto.encryptPassword(loginId: loginId, password: password)
        iotData["stamp"] = stamp
        let body: [String: any Sendable] = [
            "iotData": iotData,
            "data": ["appKey": MideaConstants.appKey, "deviceId": deviceId, "platform": "2"],
            "stamp": stamp,
        ]
        let data = try await loginStep("/mj/user/login", body)
        guard let newUid = data["uid"] as? String,
              let mdata = data["mdata"] as? [String: Any],
              let token = mdata["accessToken"] as? String,
              let encKey = data["accessToken"] as? String,
              let encIV = data["randomData"] as? String,
              let keys = try? MideaCrypto.deriveSessionKeys(encryptedKeyHex: encKey, encryptedIVHex: encIV)
        else { throw MideaCloudError.unexpectedResponse(code: 0, message: "login sem uid, token ou chaves") }
        uid = newUid
        accessToken = token
        sessionKeys = keys
    }

    /// Escolhe o servidor regional. Falha da nuvem aqui não é fatal: mantém a URL atual.
    private func reRoute() async throws {
        var body = generalData()
        body["userName"] = account
        body["platformId"] = "1"
        body["userType"] = "0"
        do {
            let response = try await send("/v1/unitcenter/router/user/name", body)
            if Self.code(of: response) == 0,
               let data = response["data"] as? [String: Any],
               let url = data["masUrl"] as? String, !url.isEmpty {
                apiURL = url
            }
        } catch MideaCloudError.unexpectedResponse {
            // mantém a URL padrão
        }
    }

    private func fetchLoginId() async throws -> String {
        var body = generalData()
        body["loginAccount"] = account
        body["type"] = "1"
        let data = try await loginStep("/v1/user/login/id/get", body)
        guard let loginId = data["loginId"] as? String else {
            throw MideaCloudError.unexpectedResponse(code: 0, message: "resposta sem loginId")
        }
        return loginId
    }

    /// Passo do login: código diferente de zero vira `invalidCredentials`.
    private func loginStep(_ endpoint: String, _ body: [String: any Sendable]) async throws -> sending [String: Any] {
        let response = try await send(endpoint, body)
        guard Self.code(of: response) == 0 else { throw MideaCloudError.invalidCredentials }
        return response["data"] as? [String: Any] ?? [:]
    }

    // MARK: - Requisição

    /// Requisição assinada. No máximo um relogin por chamada, e nenhum se a última
    /// tentativa de login foi há menos de 60 s.
    func request(_ endpoint: String, body: [String: any Sendable]) async throws -> sending [String: Any] {
        var relogged = false
        while true {
            // Com login em andamento, espera: assim a requisição sai com o token novo.
            if let running = loginTask { try await running.value }
            let tokenAtSend = accessToken
            let response = try await send(endpoint, body)
            let status = Self.code(of: response)
            if status == 0 {
                return response["data"] as? [String: Any] ?? ["message": "ok"]
            }
            if Self.isTokenInvalid(response) {
                if relogged { throw MideaCloudError.tokenInvalid }
                // Outro login já está rodando ou terminou depois do envio: espera e refaz,
                // sem iniciar outro (conta como o relogin desta requisição).
                if let running = loginTask {
                    relogged = true
                    try await running.value
                    continue
                }
                if accessToken != tokenAtSend {
                    relogged = true
                    continue
                }
                if let last = lastLoginAttempt, now().timeIntervalSince(last) < Self.reloginCooldown {
                    throw MideaCloudError.reloginThrottled
                }
                relogged = true
                try await login()
                continue
            }
            throw MideaCloudError.unexpectedResponse(code: status, message: Self.message(of: response))
        }
    }

    /// Serializa o corpo uma vez, assina esses mesmos bytes e envia. Devolve o JSON completo.
    private func send(_ endpoint: String, _ body: [String: any Sendable]) async throws -> sending [String: Any] {
        var payload = body
        if (payload["reqId"] as? String)?.isEmpty ?? true { payload["reqId"] = makeRequestId() }
        if (payload["stamp"] as? String)?.isEmpty ?? true { payload["stamp"] = formattedStamp() }
        guard let url = URL(string: apiURL + endpoint),
              let bytes = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: bytes, encoding: .utf8)
        else { throw MideaCloudError.unexpectedResponse(code: -1, message: "requisição inválida") }

        let random = String(Int(now().timeIntervalSince1970))
        var headers = [
            "content-type": "application/json; charset=utf-8",
            "secretVersion": "1",
            "sign": MideaCrypto.sign(body: text, random: random),
            "random": random,
            "x-recipe-app": MideaConstants.appId,
            "authorization": authorization,
        ]
        if !uid.isEmpty { headers["uid"] = uid }
        if let accessToken { headers["accesstoken"] = accessToken }

        let raw: Data
        do {
            raw = try await transport.post(url: url, headers: headers, body: bytes)
        } catch {
            throw MideaCloudError.network
        }
        guard let object = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              object["code"] != nil
        else {
            throw MideaCloudError.unexpectedResponse(code: -1, message: String(data: raw, encoding: .utf8) ?? "")
        }
        return object
    }

    // MARK: - Aparelhos, estado e comandos

    /// Portado de `list_appliances`. O `sn` vem cifrado com a chave de sessão.
    public func listAppliances() async throws -> [Appliance] {
        let data = try await request("/v1/appliance/user/list/get", body: generalData())
        guard let items = data["list"] as? [[String: Any]] else {
            throw MideaCloudError.unexpectedResponse(code: 0, message: "resposta sem lista de aparelhos")
        }
        return try items.compactMap { item in
            guard let idText = item["id"].flatMap({ "\($0)" }), let id = Int64(idText),
                  let typeText = item["type"] as? String,
                  let type = Int(typeText.dropFirst(typeText.hasPrefix("0x") ? 2 : 0), radix: 16)
            else { return nil }
            var sn = ""
            if let encrypted = item["sn"] as? String, !encrypted.isEmpty {
                guard let keys = sessionKeys, let plain = try? MideaCrypto.decryptWithSessionKeys(hex: encrypted, keys: keys)
                else { throw MideaCloudError.unexpectedResponse(code: 0, message: "número de série ilegível") }
                sn = plain
            }
            return Appliance(
                id: id, name: item["name"] as? String ?? "", type: type, sn: sn,
                modelNumber: item["modelNumber"] as? String ?? "0",
                manufacturerCode: item["enterpriseCode"] as? String ?? "0000",
                online: item["onlineStatus"] as? String == "1")
        }
    }

    /// Portado de `get_device_status` (consulta vazia devolve todos os atributos).
    public func status(of appliance: Appliance) async throws -> ACStatus {
        let data = try await request(
            "/v1/device/status/lua/get", body: try deviceBody(appliance, command: ["query": [String: String]()]))
        return ACStatus(
            isOn: data["power"] as? String == "on",
            mode: data["mode"] as? String ?? "",
            targetTemperature: (Self.number(data["temperature"]) ?? 0) + (Self.number(data["small_temperature"]) ?? 0) / 10,
            indoorTemperature: Self.number(data["indoor_temperature"]))
    }

    /// Portado de `send_device_control`. Aparelho offline não chama a rede.
    public func send(_ command: ACCommand, to appliance: Appliance) async throws {
        guard appliance.online else { throw MideaCloudError.applianceOffline }
        _ = try await request(
            "/v1/device/lua/control", body: try deviceBody(appliance, command: ["control": command.control]))
    }

    /// Corpo comum de estado e controle. A chave `"encryptedType "` tem espaço no fim, como na referência.
    private func deviceBody(_ appliance: Appliance, command: [String: any Sendable]) throws -> [String: any Sendable] {
        [
            "clientType": "1",
            "appId": MideaConstants.appId,
            "format": "2",
            "deviceId": deviceId,
            "iotAppId": MideaConstants.appId,
            "applianceMFCode": appliance.manufacturerCode,
            "applianceType": String(format: "0x%02X", appliance.type),
            "modelNumber": appliance.modelNumber,
            "applianceSn": try MideaCrypto.encryptWithFixedKey(appliance.sn),
            "version": "0",
            "encryptedType ": "2",
            "applianceCode": String(appliance.id),
            "command": command,
        ]
    }

    private static func number(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    // MARK: - Auxiliares

    private func generalData() -> [String: any Sendable] {
        [
            "appVersion": MideaConstants.appVersion,
            "src": MideaConstants.src,
            "format": "2",
            "stamp": formattedStamp(),
            "platformId": "1",
            "deviceId": deviceId,
            "reqId": makeRequestId(),
            "uid": uid,
            "clientType": "1",
            "appId": MideaConstants.appId,
        ]
    }

    private func formattedStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: now())
    }

    private static func code(of response: [String: Any]) -> Int {
        if let n = response["code"] as? Int { return n }
        if let s = response["code"] as? String, let n = Int(s) { return n }
        return -1
    }

    private static func message(of response: [String: Any]) -> String {
        (response["msg"] as? String) ?? (response["message"] as? String) ?? ""
    }

    /// Token inválido: código 40002 ou 7400, ou mensagem com "token" e "not exist".
    private static func isTokenInvalid(_ response: [String: Any]) -> Bool {
        let c = (response["code"] as? Int) ?? Int(response["code"] as? String ?? "") ?? -1
        if c == 40002 || c == 7400 { return true }
        let msg = message(of: response).lowercased()
        return msg.contains("token") && msg.contains("not exist")
    }
}
