import Foundation
import Security

/// Conta Midea e aparelho escolhido, guardados juntos.
public struct StoredAccount: Codable, Sendable, Equatable {
    public let account: String
    public let password: String
    public var appliance: Appliance?

    public init(account: String, password: String, appliance: Appliance? = nil) {
        self.account = account
        self.password = password
        self.appliance = appliance
    }
}

/// Onde as credenciais ficam guardadas.
public protocol CredentialStore: Sendable {
    func load() throws -> StoredAccount?
    func save(_ account: StoredAccount) throws
    func delete() throws
}

/// Erro de acesso ao Keychain, com o código `OSStatus`.
public struct KeychainError: Error, Equatable, Sendable {
    public let status: Int32
}

/// Guarda a conta como JSON em um único item genérico do Keychain.
/// `AfterFirstUnlock` permite ler em segundo plano com o iPhone bloqueado.
public struct KeychainCredentialStore: CredentialStore {
    private let service = "io.github.joaosuzxn.ar"
    private let accountKey = "midea"

    public init() {}

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: accountKey]
    }

    public func load() throws -> StoredAccount? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
        return try JSONDecoder().decode(StoredAccount.self, from: data)
    }

    public func save(_ account: StoredAccount) throws {
        let data = try JSONEncoder().encode(account)
        let update = SecItemUpdate(
            baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw KeychainError(status: update) }
        var add = baseQuery
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    public func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }
}

/// Armazenamento em memória, para testes.
final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: StoredAccount?

    func load() throws -> StoredAccount? { lock.withLock { value } }
    func save(_ account: StoredAccount) throws { lock.withLock { value = account } }
    func delete() throws { lock.withLock { value = nil } }
}
