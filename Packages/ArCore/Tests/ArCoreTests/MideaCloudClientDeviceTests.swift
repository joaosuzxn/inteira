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
private let testKeys = SessionKeys(
    key: Data("0123456789abcdef".utf8), iv: Data("fedcba9876543210".utf8))

private func loggedInClient(_ t: FakeTransport) async throws -> MideaCloudClient {
    await t.enqueue("/v1/unitcenter/router/user/name", routeOK)
    await t.enqueue("/v1/user/login/id/get", loginIdOK)
    await t.enqueue("/mj/user/login", loginOK)
    let client = MideaCloudClient(
        account: "dono@example.com", password: "senha-de-teste", transport: t,
        now: { Date(timeIntervalSince1970: 1_792_630_000) },
        makeRequestId: { "00112233445566778899aabbccddeeff" })
    try await client.login()
    return client
}

private func sampleAppliance(online: Bool = true) -> Appliance {
    Appliance(
        id: 123, name: "Ar da sala", type: 0xAC, sn: "000000P0000000Q1B88C29C963780000",
        modelNumber: "0", manufacturerCode: "0000", online: online)
}

@Test func listAppliancesDecryptsSerial() async throws {
    let t = FakeTransport()
    let client = try await loggedInClient(t)
    let keys = try #require(await client.sessionKeys)
    #expect(keys == testKeys)
    let encrypted = try MideaCrypto.aesCBCEncrypt(
        Data("SERIAL-123".utf8), key: testKeys.key, iv: testKeys.iv).hexString
    await t.enqueue(
        "/v1/appliance/user/list/get",
        """
        {"code":0,"data":{"list":[{"id":"123","name":"Ar da sala","type":"0xAC","sn":"\(encrypted)",\
        "modelNumber":"0","enterpriseCode":"0000","onlineStatus":"1"}]}}
        """)
    let list = try await client.listAppliances()
    #expect(list == [
        Appliance(
            id: 123, name: "Ar da sala", type: 0xAC, sn: "SERIAL-123",
            modelNumber: "0", manufacturerCode: "0000", online: true)
    ])
}

@Test func statusParsesLuaAttributes() async throws {
    let t = FakeTransport()
    let client = try await loggedInClient(t)
    await t.enqueue(
        "/v1/device/status/lua/get",
        #"{"code":0,"data":{"power":"on","mode":"cool","temperature":23,"small_temperature":5,"indoor_temperature":27.5}}"#)
    let appliance = sampleAppliance()
    let status = try await client.status(of: appliance)
    #expect(status == ACStatus(isOn: true, mode: "cool", targetTemperature: 23.5, indoorTemperature: 27.5))

    let req = try #require(await t.requests.last)
    let body = req.bodyJSON
    #expect(body["applianceCode"] as? String == "123")
    #expect(body["applianceType"] as? String == "0xAC")
    #expect(body["applianceSn"] as? String == (try MideaCrypto.encryptWithFixedKey(appliance.sn)))
    #expect(body["encryptedType "] as? String == "2")
    let command = body["command"] as? [String: Any]
    #expect((command?["query"] as? [String: Any])?.isEmpty == true)
}

@Test func statusWithMissingAttributesDefaults() async throws {
    let t = FakeTransport()
    let client = try await loggedInClient(t)
    await t.enqueue("/v1/device/status/lua/get", #"{"code":0,"data":{}}"#)
    let status = try await client.status(of: sampleAppliance())
    #expect(status == ACStatus(isOn: false, mode: "", targetTemperature: 0, indoorTemperature: nil))
}

@Test func sendPostsControlJSON() async throws {
    let t = FakeTransport()
    let client = try await loggedInClient(t)
    await t.enqueue("/v1/device/lua/control", #"{"code":0,"data":{}}"#)
    try await client.send(.turnOff, to: sampleAppliance())
    let req = try #require(await t.requests.last)
    #expect(req.alias == "/v1/device/lua/control")
    let control = (req.bodyJSON["command"] as? [String: Any])?["control"] as? [String: Any]
    #expect((control as NSDictionary?)?.isEqual(to: ACCommand.turnOff.control) == true)
}

@Test func offlineApplianceThrows() async throws {
    let t = FakeTransport()
    let client = try await loggedInClient(t)
    let before = await t.requests.count
    await #expect(throws: MideaCloudError.applianceOffline) {
        try await client.send(.turnOff, to: sampleAppliance(online: false))
    }
    #expect(await t.requests.count == before)
}
