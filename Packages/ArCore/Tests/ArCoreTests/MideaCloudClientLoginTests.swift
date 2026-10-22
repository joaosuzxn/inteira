import Foundation
import Testing
@testable import ArCore

private let routePath = "/v1/unitcenter/router/user/name"
private let loginIdPath = "/v1/user/login/id/get"
private let loginPath = "/mj/user/login"
private let masURL = "https://br.example/mas/v5/app/proxy?alias="

private let routeOK = #"{"code":0,"data":{"masUrl":"https://br.example/mas/v5/app/proxy?alias="}}"#
private let loginIdOK = #"{"code":0,"data":{"loginId":"login-id-test"}}"#
private let loginOK = """
{"code":0,"data":{"uid":"u1","mdata":{"accessToken":"tok"},\
"accessToken":"9c3cbae92cde658a41a2f053cd8c2daff954fb0103abc6dbb2776efddfe43629",\
"randomData":"c34d95602a528c4968ff15e7ca105d2dbe6ccfa58d0bf985b65f045fc142e318"}}
"""
private let otherPath = "/v1/test/endpoint"

/// Relógio controlável para os testes.
private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_792_630_000)
    var now: Date { lock.lock(); defer { lock.unlock() }; return current }
    func advance(_ seconds: TimeInterval) { lock.lock(); current += seconds; lock.unlock() }
}

private func enqueueLoginFlow(_ t: FakeTransport) async {
    await t.enqueue(routePath, routeOK)
    await t.enqueue(loginIdPath, loginIdOK)
    await t.enqueue(loginPath, loginOK)
}

private func makeClient(_ t: FakeTransport, clock: Clock = Clock()) -> MideaCloudClient {
    MideaCloudClient(
        account: "dono@example.com", password: "senha-de-teste", transport: t,
        now: { clock.now }, makeRequestId: { "00112233445566778899aabbccddeeff" })
}

@Test func loginRunsRouteLoginIdAndLoginInOrder() async throws {
    let t = FakeTransport()
    await enqueueLoginFlow(t)
    let client = makeClient(t)
    try await client.login()

    let reqs = await t.requests
    #expect(reqs.map(\.alias) == [routePath, loginIdPath, loginPath])
    #expect(reqs[1].url.absoluteString.hasPrefix(masURL))
    #expect(reqs[2].url.absoluteString.hasPrefix(masURL))
    let body = reqs[2].bodyJSON
    let iot = body["iotData"] as? [String: Any]
    #expect(iot?["password"] as? String == "6dd7f291d67317511f9d4e2fe1bd93f01cda26acf8aa820a2eef52cad03712ec")
    #expect(iot?["iampwd"] as? String == "818af74bc0d5b79f12f1e8f0e2546efb617d6a62f07bf9a11eee808361086185")
    #expect((body["data"] as? [String: Any])?["platform"] as? String == "2")
    #expect(await client.isLoggedIn)
}

@Test func everyRequestIsSignedOverExactBody() async throws {
    let t = FakeTransport()
    await enqueueLoginFlow(t)
    await t.enqueue(otherPath, #"{"code":0,"data":{}}"#)
    let client = makeClient(t)
    try await client.login()
    _ = try await client.request(otherPath, body: ["k": "v"])

    let reqs = await t.requests
    #expect(reqs.count == 4)
    let auth = "Basic " + Data("ac21b9f9cbfe4ca5a88562ef25e2b768:meicloud".utf8).base64EncodedString()
    for r in reqs {
        let random = try #require(r.headers["random"])
        #expect(r.headers["sign"] == MideaCrypto.sign(body: r.bodyText, random: random))
        #expect(r.headers["secretVersion"] == "1")
        #expect(r.headers["x-recipe-app"] == "1010")
        #expect(r.headers["authorization"] == auth)
    }
    #expect(reqs[0].headers["accesstoken"] == nil)
    #expect(reqs[3].headers["accesstoken"] == "tok")
    #expect(reqs[3].headers["uid"] == "u1")
    #expect(reqs[3].alias == otherPath)
}

@Test func wrongPasswordThrowsInvalidCredentials() async throws {
    let t = FakeTransport()
    await t.enqueue(routePath, routeOK)
    await t.enqueue(loginIdPath, loginIdOK)
    await t.enqueue(loginPath, #"{"code":1,"msg":"password error"}"#)
    let client = makeClient(t)
    await #expect(throws: MideaCloudError.invalidCredentials) { try await client.login() }
    #expect(await client.isLoggedIn == false)
}

@Test func tokenInvalidReloginsOnceThenRetries() async throws {
    let t = FakeTransport()
    let clock = Clock()
    await enqueueLoginFlow(t)
    let client = makeClient(t, clock: clock)
    try await client.login()

    clock.advance(120)
    await t.enqueue(otherPath, #"{"code":40002}"#)
    await enqueueLoginFlow(t)
    await t.enqueue(otherPath, #"{"code":0,"data":{}}"#)
    _ = try await client.request(otherPath, body: [:])

    let aliases = await t.requests.map(\.alias)
    #expect(aliases == [routePath, loginIdPath, loginPath, otherPath,
                        routePath, loginIdPath, loginPath, otherPath])
}

@Test func tokenInvalidWithin60sDoesNotLoginAgain() async throws {
    let t = FakeTransport()
    let clock = Clock()
    await enqueueLoginFlow(t)
    let client = makeClient(t, clock: clock)
    try await client.login()

    clock.advance(120)
    await t.enqueue(otherPath, #"{"code":40002}"#)
    await enqueueLoginFlow(t)
    await t.enqueue(otherPath, #"{"code":0,"data":{}}"#)
    _ = try await client.request(otherPath, body: [:])

    clock.advance(30)
    await t.enqueue(otherPath, #"{"code":40002}"#)
    let before = await t.requests.count
    await #expect(throws: MideaCloudError.reloginThrottled) { try await client.request(otherPath, body: [:]) }
    #expect(await t.requests.count == before + 1)
}

@Test func tokenInvalidAfterRetryThrowsTokenInvalid() async throws {
    let t = FakeTransport()
    let clock = Clock()
    await enqueueLoginFlow(t)
    let client = makeClient(t, clock: clock)
    try await client.login()

    clock.advance(120)
    await t.enqueue(otherPath, #"{"code":40002}"#)
    await enqueueLoginFlow(t)
    await t.enqueue(otherPath, #"{"code":40002}"#)
    await #expect(throws: MideaCloudError.tokenInvalid) { try await client.request(otherPath, body: [:]) }
    #expect(await t.requests.map(\.alias).filter { $0 == loginPath }.count == 2)
}

@Test func garbageResponseIsUnexpected() async throws {
    let t = FakeTransport()
    await t.enqueue(otherPath, "<html>")
    await t.enqueue(otherPath, #"{"code":9999,"msg":"x"}"#)
    let client = makeClient(t)
    await #expect(throws: MideaCloudError.unexpectedResponse(code: -1, message: "<html>")) {
        try await client.request(otherPath, body: [:])
    }
    await #expect(throws: MideaCloudError.unexpectedResponse(code: 9999, message: "x")) {
        try await client.request(otherPath, body: [:])
    }
}

@Test func transportErrorIsNetwork() async throws {
    let t = FakeTransport()
    let client = makeClient(t)
    await #expect(throws: MideaCloudError.network) { try await client.request(otherPath, body: [:]) }
    await #expect(throws: MideaCloudError.network) { try await client.login() }
}
