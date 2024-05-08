#if os(macOS)
    @testable import Cache
    import Cocoa

    extension NSImage {
        func isEqualToImage(_ image: NSImage) -> Bool {
            self.data == image.data
        }

        var data: Data {
            let representation = tiffRepresentation!
            let imageFileType: NSBitmapImageRep.FileType = .png

            return NSBitmapImageRep(data: representation)!
                .representation(using: imageFileType, properties: [:])!
        }
    }
#endif
