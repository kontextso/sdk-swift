struct UpdateSKStoreProductIFrameDataDTO: Encodable, Sendable {
    let type: String = "update-skstoreproduct-iframe"
    let data: Data
}

extension UpdateSKStoreProductIFrameDataDTO {
    struct Data: Encodable, Sendable {
        let code: String
        let open: Bool
    }
}
