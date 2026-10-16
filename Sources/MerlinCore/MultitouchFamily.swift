import Foundation

/// MultitouchSupport aygıt ailesinden aygıt türü.
public enum MultitouchFamily {
    /// Magic Mouse aile kimlikleri.
    public static let magicMouseFamilies: ClosedRange<Int> = 112...127

    /// Dahili aygıt her zaman trackpad'dir; dahili olmayan 112…127 Magic Mouse, diğerleri harici Magic Trackpad.
    /// Aile okunamadıysa (negatif) ve dahili değilse nil: köprü bu aygıtı fare olarak başlatır, trackpad sayılmaz.
    public static func kind(familyID: Int, isBuiltIn: Bool) -> InputDeviceKind? {
        if isBuiltIn { return .trackpad }
        if familyID < 0 { return nil }
        return magicMouseFamilies.contains(familyID) ? .magicMouse : .trackpad
    }
}
