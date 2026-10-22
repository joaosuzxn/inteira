import Foundation
import Testing
@testable import ArCore

private let routeOK = #"{"code":0,"data":{"masUrl":"https://br.example/mas/v5/app/proxy?alias="}}"#
private let loginIdOK = #"{"code":0,"data":{"loginId":"login-id-test"}}"#
private let loginOK = """
{"code":0,"data":{"uid":"u1","mdata":{"accessToken":"tok"},\
"accessToken":"9c3cbae92cde658a41a2f053cd8c2daff954fb0103abc6dbb2776efddfe43629",\
"randomData":"c34d95602a528c4968ff15e7ca105d2dbe6ccfa58d0bf985b65f045fc142e318"}}
"""
private let keys = SessionKeys(key: Data("0123456789abcdef".utf8), iv: Data("fedcba9876543210".utf8))

private func enqueueLogin(_ t: FakeTransport) async {
    await t.enqueue("/v1/unitcenter/router/user/name", routeOK)
    await t.enqueue("/v1/user/login/id/get", loginIdOK)
    await t.enqueue("/mj/user/login", loginOK)
}

private func enqueueList(_ t: FakeTransport, online: Bool) async throws {
    let sn = try MideaCrypto.aesCBCEncrypt(Data("SERIAL-123".utf8), key: keys.key, iv: keys.iv).hexString
    await t.enqueue(
        "/v1/appliance/user/list/get",
        """
        {"code":0,"data":{"list":[{"id":"123","name":"Ar da sala","type":"0xAC","sn":"\(sn)",\
        "modelNumber":"0","enterpriseCode":"0000","onlineStatus":"\(online ? "1" : "0")"}]}}
        """)
}

private func appliance(online: Bool) -> Appliance {
    Appliance(
        id: 123, name: "Ar da sala", type: 0xAC, sn: "SERIAL-123",
        modelNumber: "0", manufacturerCode: "0000", online: online)
}

@Test func signInSavesCredentialsAndReturnsAppliances() async throws {
    let t = FakeTransport()
    let store = InMemoryCredentialStore()
    await enqueueLogin(t)
    try await enqueueList(t, online: true)
    let service = AirConditionerService(store: store, transport: t)
    #expect(await service.isConfigured == false)
    let list = try await service.signIn(account: "dono@example.com", password: "senha-de-teste")
    #expect(list == [appliance(online: true)])
    #expect(try store.load() == StoredAccount(
        account: "dono@example.com", password: "senha-de-teste", appliance: appliance(online: true)))
    #expect(await service.isConfigured)
}

@Test func sendWithoutConfigurationThrows() async throws {
    let t = FakeTransport()
    let service = AirConditionerService(store: InMemoryCredentialStore(), transport: t)
    await #expect(throws: MideaCloudError.invalidCredentials) { try await service.send(.turnOff) }
    await #expect(throws: MideaCloudError.invalidCredentials) { _ = try await service.status() }
    #expect(await t.requests.isEmpty)
}

@Test func signOutDeletesCredentials() async throws {
    let store = InMemoryCredentialStore()
    try store.save(StoredAccount(account: "a", password: "b", appliance: nil))
    let service = AirConditionerService(store: store, transport: FakeTransport())
    #expect(await service.isConfigured)
    try await service.signOut()
    #expect(try store.load() == nil)
    #expect(await service.isConfigured == false)
}

@Test func sendWithoutSelectedApplianceThrows() async throws {
    let t = FakeTransport()
    let store = InMemoryCredentialStore()
    try store.save(StoredAccount(account: "a", password: "b", appliance: nil))
    let service = AirConditionerService(store: store, transport: t)
    await #expect(throws: MideaCloudError.unexpectedResponse(code: -2, message: "nenhum aparelho selecionado")) {
        try await service.send(.turnOff)
    }
    #expect(await t.requests.isEmpty)
}

@Test func selectSavesAppliance() async throws {
    let store = InMemoryCredentialStore()
    try store.save(StoredAccount(account: "a", password: "b", appliance: nil))
    let service = AirConditionerService(store: store, transport: FakeTransport())
    try await service.select(appliance(online: true))
    #expect(try store.load()?.appliance == appliance(online: true))
}

@Test func staleOfflineFlagIsRefreshedFromCloud() async throws {
    let t = FakeTransport()
    let store = InMemoryCredentialStore()
    try store.save(StoredAccount(account: "dono@example.com", password: "senha-de-teste", appliance: appliance(online: false)))
    await enqueueLogin(t)
    try await enqueueList(t, online: true)
    await t.enqueue("/v1/device/lua/control", #"{"code":0,"data":{}}"#)
    let service = AirConditionerService(store: store, transport: t)
    try await service.send(.turnOff)
    #expect(await t.requests.last?.alias == "/v1/device/lua/control")
    #expect(try store.load()?.appliance?.online == true)
}

@Test func reallyOfflineApplianceThrowsAfterRefresh() async throws {
    let t = FakeTransport()
    let store = InMemoryCredentialStore()
    try store.save(StoredAccount(account: "dono@example.com", password: "senha-de-teste", appliance: appliance(online: false)))
    await enqueueLogin(t)
    try await enqueueList(t, online: false)
    let service = AirConditionerService(store: store, transport: t)
    await #expect(throws: MideaCloudError.applianceOffline) { try await service.send(.turnOff) }
    #expect(await t.requests.contains { $0.alias == "/v1/device/lua/control" } == false)
}

@Test func statusUsesSelectedAppliance() async throws {
    let t = FakeTransport()
    let store = InMemoryCredentialStore()
    try store.save(StoredAccount(account: "dono@example.com", password: "senha-de-teste", appliance: appliance(online: true)))
    await enqueueLogin(t)
    try await enqueueList(t, online: true)
    await t.enqueue("/v1/device/status/lua/get", #"{"code":0,"data":{"power":"on","mode":"cool","temperature":24}}"#)
    let service = AirConditionerService(store: store, transport: t)
    let status = try await service.status()
    #expect(status.isOn)
    #expect(status.targetTemperature == 24)
}
