import Foundation

/// Controla o ar escolhido pela conta salva. O cliente da nuvem nasce sob demanda;
/// o relogin por token expirado é do próprio cliente.
public actor AirConditionerService: ACControlling {
    private let store: any CredentialStore
    private let transport: any HTTPTransport
    private var client: MideaCloudClient?
    /// Já atualizou o aparelho a partir da nuvem nesta sessão do cliente.
    private var refreshed = false

    public init(store: any CredentialStore, transport: any HTTPTransport) {
        self.store = store
        self.transport = transport
    }

    public var isConfigured: Bool { ((try? store.load()) ?? nil) != nil }

    /// Entra na conta, guarda as credenciais e devolve os aparelhos.
    /// Com um só aparelho, ele já fica selecionado.
    public func signIn(account: String, password: String) async throws -> [Appliance] {
        let newClient = MideaCloudClient(account: account, password: password, transport: transport)
        try await newClient.login()
        let list = try await newClient.listAppliances()
        try store.save(StoredAccount(account: account, password: password, appliance: list.count == 1 ? list[0] : nil))
        client = newClient
        refreshed = true
        return list
    }

    public func select(_ appliance: Appliance) async throws {
        guard var stored = try store.load() else { throw MideaCloudError.invalidCredentials }
        stored.appliance = appliance
        try store.save(stored)
    }

    public func signOut() async throws {
        try store.delete()
        client = nil
        refreshed = false
    }

    public func status() async throws -> ACStatus {
        let (client, appliance, _) = try await prepare()
        return try await client.status(of: appliance)
    }

    public func send(_ command: ACCommand) async throws {
        var (client, appliance, justRefreshed) = try await prepare()
        // Antes de desistir por "offline", confere na nuvem: o aviso guardado pode estar velho.
        if !appliance.online && !justRefreshed { appliance = try await refresh(client, appliance) }
        try await client.send(command, to: appliance)
    }

    /// Credenciais, aparelho e cliente logado. Na primeira ação da sessão, atualiza o aparelho.
    private func prepare() async throws -> (MideaCloudClient, Appliance, Bool) {
        guard let stored = try store.load() else { throw MideaCloudError.invalidCredentials }
        guard let appliance = stored.appliance else {
            throw MideaCloudError.unexpectedResponse(code: -2, message: "nenhum aparelho selecionado")
        }
        let current = client ?? MideaCloudClient(account: stored.account, password: stored.password, transport: transport)
        client = current
        if !(await current.isLoggedIn) { try await current.login() }
        if refreshed { return (current, appliance, false) }
        let updated = try await refresh(current, appliance)
        return (current, updated, true)
    }

    /// Relê a lista da nuvem e guarda a versão atual do aparelho.
    private func refresh(_ client: MideaCloudClient, _ appliance: Appliance) async throws -> Appliance {
        let list = try await client.listAppliances()
        refreshed = true
        guard let fresh = list.first(where: { $0.id == appliance.id }), fresh != appliance else { return appliance }
        if var stored = try store.load() {
            stored.appliance = fresh
            try store.save(stored)
        }
        return fresh
    }
}
