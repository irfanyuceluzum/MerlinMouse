import Foundation

/// Bir görselin alfa kanalından gövdenin sınır kutusunu bulur (gölge ve boşluk kırpılsın diye).
public enum AlphaBounds {
    /// Alfa değeri `threshold`'un ÜSTÜNDEKİ piksellerin sınır kutusu; hiç yoksa nil.
    /// `alpha` satır satır, `width * height` uzunluğunda olmalı.
    public static func opaqueRect(width: Int, height: Int, alpha: [UInt8], threshold: UInt8)
        -> (x: Int, y: Int, width: Int, height: Int)? {
        guard width > 0, height > 0, alpha.count >= width * height else { return nil }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = y * width
            for x in 0..<width where alpha[row + x] > threshold {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= 0 else { return nil }
        return (minX, minY, maxX - minX + 1, maxY - minY + 1)
    }
}
