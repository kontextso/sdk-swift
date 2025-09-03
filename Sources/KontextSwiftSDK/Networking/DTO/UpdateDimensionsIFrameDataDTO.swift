import Foundation

struct UpdateDimensionsIFrameDataDTO: Encodable {
    let type: String = "update-dimensions-iframe"
    let data: Data
}

extension UpdateDimensionsIFrameDataDTO {
    struct Data: Encodable {
        let screenWidth: CGFloat
        let screenHeight: CGFloat
        let containerWidth: CGFloat
        let containerHeight: CGFloat
        let containerX: CGFloat
        let containerY: CGFloat
    }
}
