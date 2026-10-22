/// Constantes do protocolo MSmartHome.
/// Fonte: sususweet/midea_auto_cloud @ ce0c4b88224def0f6b53714312c19f71aa9c2a50 (Apache-2.0).
enum MideaConstants {
    static let baseURL = "https://mp-prod.appsmb.com/mas/v5/app/proxy?alias="
    static let appId = "1010"
    static let src = "10"
    static let appVersion = "3.0.2"
    static let appKey = "ac21b9f9cbfe4ca5a88562ef25e2b768"
    static let iotKey = "meicloud"
    static let hmacKey = "PROD_VnoClJI9aikS8dyy"
    /// Usados como bytes ASCII (16 bytes cada).
    static let fixedKey = "b5d1453ec418536a"
    static let fixedIV = "e3ffc17cf1fe23ac"
}
