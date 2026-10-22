import ArCore
import Darwin
import Foundation

// Spike contra a nuvem real da Midea. Roda só na mão do dono (nunca em teste).
// Não imprime token, sn, senha, uid nem corpo de resposta: só passo, resultado e erro.

func fail(_ message: String) -> Never {
    print(message)
    exit(1)
}

func describe(_ error: Error) -> String {
    guard let cloud = error as? MideaCloudError else { return "erro inesperado" }
    let name: String
    switch cloud {
    case .invalidCredentials: name = "invalidCredentials"
    case .tokenInvalid: name = "tokenInvalid"
    case .reloginThrottled: name = "reloginThrottled"
    case .applianceOffline: name = "applianceOffline"
    case .network: name = "network"
    case .unexpectedResponse(let code, _): name = "unexpectedResponse(code: \(code))"
    }
    return "\(name) — \(cloud.userMessage)"
}

func readPassword() -> String? {
    var buffer = [CChar](repeating: 0, count: 256)
    guard readpassphrase("Senha da conta SmartHome: ", &buffer, buffer.count, 0) != nil else { return nil }
    let length = buffer.firstIndex(of: 0) ?? buffer.count
    let text = String(decoding: buffer[..<length].map { UInt8(bitPattern: $0) }, as: UTF8.self)
    buffer.withUnsafeMutableBufferPointer { $0.update(repeating: 0) }
    return text
}

func confirm(_ question: String) -> Bool {
    print("\(question) [s/N] ", terminator: "")
    fflush(stdout)
    let answer = readLine()?.trimmingCharacters(in: .whitespaces).lowercased()
    return answer == "s" || answer == "sim"
}

func show(_ step: Int, _ status: ACStatus) {
    let indoor = status.indoorTemperature.map { String($0) } ?? "n/d"
    print("[\(step)] estado: ligado=\(status.isOn) modo=\(status.mode) alvo=\(status.targetTemperature) interna=\(indoor)")
}

guard let account = ProcessInfo.processInfo.environment["AR_MIDEA_ACCOUNT"], !account.isEmpty else {
    fail("Defina a conta: AR_MIDEA_ACCOUNT=<e-mail> swift run --package-path Packages/ArCore ar-spike")
}
guard let password = readPassword(), !password.isEmpty else { fail("Senha não informada.") }

let transport = URLSessionTransport()
let client = MideaCloudClient(account: account, password: password, transport: transport)

do {
    // Passo 1: login (uma única tentativa; se falhar, para).
    print("[1] login...")
    do { try await client.login() } catch { fail("[1] falhou: \(describe(error))") }
    print("[1] login ok")

    // Passo 2: aparelhos.
    print("[2] listando aparelhos...")
    let appliances = try await client.listAppliances()
    for item in appliances {
        print("[2] \(item.name) tipo=0x\(String(item.type, radix: 16, uppercase: true)) online=\(item.online)")
    }
    guard let ac = appliances.first(where: { $0.type == 0xAC }) else { fail("[2] nenhum ar-condicionado (0xAC) na conta.") }
    print("[2] usando: \(ac.name)")

    // Passo 3: estado.
    show(3, try await client.status(of: ac))

    // Passo 4: ligar.
    if confirm("[4] Ligar em 23 °C?") {
        try await client.send(.turnOn(temperature: 23), to: ac)
        print("[4] comando enviado; aguardando 10 s...")
        try await Task.sleep(for: .seconds(10))
        show(4, try await client.status(of: ac))
    } else {
        print("[4] pulado")
    }

    // Passo 5: desligar.
    if confirm("[5] Desligar?") {
        try await client.send(.turnOff, to: ac)
        print("[5] comando enviado; aguardando 10 s...")
        try await Task.sleep(for: .seconds(10))
        show(5, try await client.status(of: ac))
    } else {
        print("[5] pulado")
    }

    // Passo 6: a segunda sessão derruba a primeira?
    print("[6] segunda sessão com a mesma conta...")
    let second = MideaCloudClient(account: account, password: password, transport: transport)
    do { try await second.login() } catch { fail("[6] login da sessão 2 falhou: \(describe(error))") }
    do {
        _ = try await client.status(of: ac)
        print("[6] sessão 1 continua válida")
    } catch {
        print("[6] sessão 1 derrubada: \(describe(error))")
    }
} catch {
    fail("falhou: \(describe(error))")
}
