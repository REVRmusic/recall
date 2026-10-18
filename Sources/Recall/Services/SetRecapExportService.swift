import Foundation
import AppKit
import SwiftUI
import Photos

/// Service d'exportation visuelle et de partage du récapitulatif statistique de mix (Set Recap)
@MainActor
public final class SetRecapExportService {
    public static let shared = SetRecapExportService()
    
    private init() {}
    
    // MARK: - 1. Génération de l'image haute définition
    
    /// Génère un rendu image haute résolution (Retina @2x) de l'intégralité du bilan statistique
    public func generateImage(
        stats: SetRecapStats,
        sessionStartTime: Date,
        sessionEndTime: Date? = nil,
        eventTitle: String? = nil,
        hideDuration: Bool = false
    ) -> NSImage? {
        let exportView = SetRecapExportCardView(
            stats: stats,
            sessionStartTime: sessionStartTime,
            sessionEndTime: sessionEndTime,
            eventTitle: eventTitle,
            generationDate: Date(),
            hideDuration: hideDuration
        )
        
        // 1. Priorité moderne : ImageRenderer SwiftUI (macOS 13+)
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 2.0 // Qualité Retina 2x
        renderer.isOpaque = true
        
        if let image = renderer.nsImage {
            return image
        }
        
        // 2. Secours bitmap haute fidélité via NSHostingView
        let hostingView = NSHostingView(rootView: exportView)
        let fittingSize = hostingView.fittingSize
        let targetSize = NSSize(width: 560, height: max(fittingSize.height, 750))
        hostingView.frame = NSRect(origin: .zero, size: targetSize)
        hostingView.layoutSubtreeIfNeeded()
        
        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return nil
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
        let fallbackImage = NSImage(size: targetSize)
        fallbackImage.addRepresentation(rep)
        return fallbackImage
    }
    
    // MARK: - 2. Enregistrement direct dans l'application Photos de macOS
    
    /// Enregistre directement l'image du bilan dans la photothèque Photos de macOS
    public func saveToPhotos(image: NSImage, completion: @escaping (Bool, String?) -> Void) {
        guard let pngData = convertToPngData(image: image) else {
            completion(false, "Impossible de générer le fichier image PNG.")
            return
        }
        
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileName = "Recall_Bilan_Mix_\(Int(Date().timeIntervalSince1970)).png"
        let tempFile = tempDir.appendingPathComponent(fileName)
        
        do {
            try pngData.write(to: tempFile)
        } catch {
            completion(false, "Erreur écriture temporaire : \(error.localizedDescription)")
            return
        }
        
        // Tentative 1 : Framework Photos natif (PHPhotoLibrary addOnly)
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempFile)
                    }) { success, err in
                        DispatchQueue.main.async {
                            if success {
                                try? FileManager.default.removeItem(at: tempFile)
                                AppLogger.info("Bilan de set enregistré dans l'application Photos avec succès (PHPhotoLibrary)", category: .export)
                                completion(true, nil)
                            } else {
                                // En cas d'échec PHPhotoLibrary, on essaie le secours AppleScript
                                self?.importToPhotosViaAppleScript(filePath: tempFile.path, completion: completion)
                            }
                        }
                    }
                } else {
                    // Tentative 2 : Secours direct AppleScript Photos (sans nécessiter de permission TCC invasive)
                    self?.importToPhotosViaAppleScript(filePath: tempFile.path, completion: completion)
                }
            }
        }
    }
    
    /// Secours AppleScript pour importer une image directement dans Photos.app
    private func importToPhotosViaAppleScript(filePath: String, completion: @escaping (Bool, String?) -> Void) {
        guard FileManager.default.fileExists(atPath: filePath) else {
            AppLogger.error("Fichier image temporaire introuvable pour Photos", category: .export)
            completion(false, "Fichier image temporaire introuvable.")
            return
        }
        
        let escapedPath = filePath.replacingOccurrences(of: "\"", with: "\\\"")
        let scriptSource = """
        tell application "Photos"
            try
                import {POSIX file "\(escapedPath)"} skip check duplicates true
                return "SUCCESS"
            on error errMsg
                return errMsg
            end try
        end tell
        """
        
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: scriptSource) {
                let output = scriptObject.executeAndReturnError(&error)
                let resultString = output.stringValue ?? ""
                
                try? FileManager.default.removeItem(atPath: filePath)
                
                DispatchQueue.main.async {
                    if resultString == "SUCCESS" {
                        AppLogger.info("Bilan de set importé dans l'application Photos via AppleScript", category: .export)
                        completion(true, nil)
                    } else {
                        let errDesc = error?[NSAppleScript.errorMessage] as? String ?? resultString
                        AppLogger.error("Échec importation Photos : \(errDesc)", category: .export)
                        completion(false, "Photos nécessite l'autorisation d'importation : \(errDesc)")
                    }
                }
            } else {
                try? FileManager.default.removeItem(atPath: filePath)
                DispatchQueue.main.async {
                    AppLogger.error("Impossible d'exécuter la commande AppleScript vers Photos", category: .export)
                    completion(false, "Impossible d'exécuter la commande vers Photos.")
                }
            }
        }
    }
    
    // MARK: - 3. Menu de Partage Natif macOS (AirDrop, Messages, Mail, etc.)
    
    /// Présente le menu de partage natif macOS sous le composant ou la fenêtre spécifiée
    public func shareImage(
        image: NSImage,
        positioningView: NSView? = nil,
        window: NSWindow? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard let pngData = convertToPngData(image: image) else {
            completion?(false)
            return
        }
        
        let dateStr = formattedDateForFilename(Date())
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let tempFile = tempDir.appendingPathComponent("Recall-Bilan-Mix-\(dateStr).png")
        
        do {
            try pngData.write(to: tempFile)
        } catch {
            completion?(false)
            return
        }
        
        guard let targetView = positioningView ?? window?.contentView ?? NSApp.keyWindow?.contentView else {
            completion?(false)
            return
        }
        
        let anchorRect = positioningView != nil ? targetView.bounds : NSRect(x: targetView.bounds.midX - 10, y: 25, width: 20, height: 20)
        let picker = NSSharingServicePicker(items: [tempFile])
        picker.show(relativeTo: anchorRect, of: targetView, preferredEdge: .minY)
        completion?(true)
    }
    
    // MARK: - 4. Enregistrer sous (Fichier PNG)
    
    /// Ouvre la boîte de dialogue système pour enregistrer le fichier image sur le Mac (Bureau, Téléchargements...)
    public func saveImageToFile(
        image: NSImage,
        window: NSWindow?,
        completion: @escaping (Bool) -> Void
    ) {
        guard let pngData = convertToPngData(image: image) else {
            completion(false)
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "Recall-Bilan-Mix-\(formattedDateForFilename(Date())).png"
        savePanel.allowedContentTypes = [.png]
        savePanel.prompt = "Enregistrer le bilan"
        savePanel.message = "Choisissez l'emplacement pour enregistrer l'image des statistiques de votre mix."
        
        let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
            if response == .OK, let targetURL = savePanel.url {
                do {
                    try pngData.write(to: targetURL)
                    completion(true)
                } catch {
                    completion(false)
                }
            } else {
                completion(false)
            }
        }
        
        if let win = window {
            savePanel.beginSheetModal(for: win, completionHandler: handleResponse)
        } else {
            let res = savePanel.runModal()
            handleResponse(res)
        }
    }
    
    // MARK: - 5. Copie directe dans le Presse-Papier
    
    /// Copie directement l'image PNG et TIFF dans le presse-papier macOS pour un collage immédiat (iMessage, WhatsApp, Instagram...)
    public func copyImageToClipboard(image: NSImage) -> Bool {
        guard let pngData = convertToPngData(image: image) else { return false }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        let success = pasteboard.setData(pngData, forType: .png)
        if let tiff = image.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
        return success
    }
    
    // MARK: - Utilitaires
    
    public func convertToPngData(image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
    
    private func formattedDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH'h'mm"
        return formatter.string(from: date)
    }
}
