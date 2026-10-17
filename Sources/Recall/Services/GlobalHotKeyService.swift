import Foundation
import Carbon
import AppKit
import Combine
import SwiftUI

public extension Notification.Name {
    static let recallTriggerSearch = Notification.Name("recallTriggerSearch")
    static let recallTriggerGuide = Notification.Name("recallTriggerGuide")
}

/// Service de gestion des raccourcis clavier globaux système via Carbon EventHotKey
/// Permet de contrôler Recall à la volée pendant le mix même si Serato ou Rekordbox est actif au premier plan
public final class GlobalHotKeyService: ObservableObject {
    public static let shared = GlobalHotKeyService()
    
    // Identifiants uniques des actions
    private enum ActionId: UInt32 {
        // Combinaisons Cmd + Shift (⇧⌘)
        case toggleVisibilityShift = 101
        case toggleCompactShift = 102
        case openSearchShift = 103
        
        // Combinaisons Cmd + Option (⌥⌘)
        case toggleVisibilityOption = 201
        case toggleCompactOption = 202
        case openSearchOption = 203
    }
    
    private var registeredHotKeys: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private var isHandlerInstalled: Bool = false
    
    private init() {
        installCarbonHandler()
    }
    
    deinit {
        unregisterAll()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
        }
    }
    
    /// Installe le gestionnaire d'événements Carbon global
    private func installCarbonHandler() {
        guard !isHandlerInstalled else { return }
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let callback: EventHandlerUPP = { (_, eventRef, _) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr {
                GlobalHotKeyService.shared.handleHotKey(id: hotKeyID.id)
            }
            return noErr
        }
        
        let installErr = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
        
        if installErr == noErr {
            isHandlerInstalled = true
        }
    }
    
    /// Met à jour les enregistrements globaux selon le préréglage actif
    public func updateRegistrations(preset: HotKeyModifierPreset) {
        unregisterAll()
        guard preset != .disabled else { return }
        
        let signature = OSType(0x5245434C) // "RECL"
        
        // Keycodes standards Carbon ANSI
        let kR = UInt32(kVK_ANSI_R) // 15
        let kC = UInt32(kVK_ANSI_C) // 8
        let kF = UInt32(kVK_ANSI_F) // 3
        
        // 1. Raccourcis Cmd + Shift (⇧⌘)
        if preset == .cmdShift || preset == .both {
            let shiftModifiers = UInt32(cmdKey | shiftKey)
            registerKey(keyCode: kR, modifiers: shiftModifiers, id: ActionId.toggleVisibilityShift.rawValue, signature: signature)
            registerKey(keyCode: kC, modifiers: shiftModifiers, id: ActionId.toggleCompactShift.rawValue, signature: signature)
            registerKey(keyCode: kF, modifiers: shiftModifiers, id: ActionId.openSearchShift.rawValue, signature: signature)
        }
        
        // 2. Raccourcis Cmd + Option (⌥⌘) - Anti-conflit Serato & Rekordbox
        if preset == .cmdOption || preset == .both {
            let optionModifiers = UInt32(cmdKey | optionKey)
            registerKey(keyCode: kR, modifiers: optionModifiers, id: ActionId.toggleVisibilityOption.rawValue, signature: signature)
            registerKey(keyCode: kC, modifiers: optionModifiers, id: ActionId.toggleCompactOption.rawValue, signature: signature)
            registerKey(keyCode: kF, modifiers: optionModifiers, id: ActionId.openSearchOption.rawValue, signature: signature)
        }
    }
    
    private func registerKey(keyCode: UInt32, modifiers: UInt32, id: UInt32, signature: OSType) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr, let ref = hotKeyRef {
            registeredHotKeys.append(ref)
        }
    }
    
    /// Désenregistre tous les raccourcis système
    public func unregisterAll() {
        for ref in registeredHotKeys {
            UnregisterEventHotKey(ref)
        }
        registeredHotKeys.removeAll()
    }
    
    /// Traite l'exécution de l'action associée à la touche pressée
    public func handleHotKey(id: UInt32) {
        DispatchQueue.main.async { [weak self] in
            switch id {
            case ActionId.toggleVisibilityShift.rawValue,
                 ActionId.toggleVisibilityOption.rawValue:
                self?.performToggleVisibility()
                
            case ActionId.toggleCompactShift.rawValue,
                 ActionId.toggleCompactOption.rawValue:
                self?.performToggleCompact()
                
            case ActionId.openSearchShift.rawValue,
                 ActionId.openSearchOption.rawValue:
                self?.performOpenSearch()
                
            default:
                break
            }
        }
    }
    
    // MARK: - Actions concrètes
    
    /// Action 1 : Afficher / Masquer Recall instantanément
    public func performToggleVisibility() {
        guard let window = FloatingWindowController.shared.window else { return }
        
        if window.isVisible {
            window.orderOut(nil)
        } else {
            FloatingWindowController.shared.show()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    /// Action 2 : Basculer entre mode normal et bandeau compact
    public func performToggleCompact() {
        let newCompact = !UserSettings.shared.isCompactMode
        withAnimation(.easeInOut(duration: 0.28)) {
            UserSettings.shared.isCompactMode = newCompact
            FloatingWindowController.shared.toggleCompactMode(newCompact)
        }
        FloatingWindowController.shared.show()
    }
    
    /// Action 3 : Ouvrir la recherche Recall par-dessus le logiciel DJ
    public func performOpenSearch() {
        FloatingWindowController.shared.show()
        NSApp.activate(ignoringOtherApps: true)
        
        // Si la fenêtre est en bandeau compact, on bascule en mode normal pour avoir l'espace d'afficher les résultats
        if UserSettings.shared.isCompactMode {
            withAnimation(.easeInOut(duration: 0.28)) {
                UserSettings.shared.isCompactMode = false
                FloatingWindowController.shared.toggleCompactMode(false)
            }
        }
        
        NotificationCenter.default.post(name: .recallTriggerSearch, object: nil)
    }
}
