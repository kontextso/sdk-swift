/// Protocol to provide functionality for data model conversion.
public protocol ModelConvertible {
    associatedtype Model

    /// Converts a conforming instance to a data model instance.
    /// - Returns: The converted data model instance.
    func toModel() -> Model
}
