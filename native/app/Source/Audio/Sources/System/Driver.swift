//
//  Driver.swift
//  eqMac
//
//  Created by Roman Kisil on 30/10/2018.
//  Copyright © 2018 Roman Kisil. All rights reserved.
//

import Foundation
import AMCoreAudio
import CoreFoundation

enum DriverDevice {
  case passthrough
  case ui
  case null
}

enum DriverDeviceIsActiveProperty: String {
  case passthrough = "deva"
  case ui = "uida"
  case null = "nuld"
}

enum CustomProperties: String {
  case kAudioDeviceCustomPropertyLatency = "cltc"
  case kAudioDeviceCustomPropertySafetyOffset = "csfo"
  case kAudioDeviceCustomPropertyShown = "shwn"
  case kAudioDeviceCustomPropertyVersion = "vrsn"
}

class Driver {
//  static var legacyIsInstalled: Bool {
//    get {
//      for legacyDriverUID in Constants.LEGACY_DRIVER_UIDS {
//        let device = AudioDevice.getOutputDeviceFromUID(UID: legacyDriverUID)
//        if (device != nil) { return true }
//      }
//      return false
//    }
//  }
//
  static var pluginId: AudioObjectID? {
    return AudioDevice.lookupIDByPluginBundleID(by: Constants.DRIVER_BUNDLE_ID)
  }
  
  static var isInstalled: Bool {
    get {
      return self.device != nil || self.pluginId != nil
    }
  }

  static var info: Dictionary<String, Any> {
    return NSDictionary(contentsOfFile: Bundle.main.path(forResource: "Info", ofType: "plist", inDirectory: "Embedded/eqMac.driver/Contents")!) as! Dictionary<String, Any>
  }

  static var bundledVersion: String {
    return info["CFBundleVersion"] as! String
  }

  static var sampleRates: [Double] {
    return [
      8_000,
      11_025,
      12_000,
      16_000,
      22_050,
      24_000,
      32_000,
      44_100,
      48_000,
      64_000,
      88_200,
      96_000,
      128_000,
      176_400,
      192_000
    ]
  }
  
  static func getDeviceIsActive (device: DriverDevice) -> Bool {
    if Driver.device != nil { return true }
    if let pluginId = self.pluginId {
      var address = AudioObjectPropertyAddress(
        mSelector: getPropertySelectorFromString(getDeviceIsActiveProperty(device).rawValue),
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster
      )
      
      var active = kCFBooleanFalse
      var size: UInt32 = UInt32(MemoryLayout<CFBoolean>.size)
      
      checkErr(AudioObjectGetPropertyData(pluginId, &address, 0, nil, &size, &active))
      
      return CFBooleanGetValue(active)
    }
    return false
  }
  
  private static func setDeviceIsActive (device: DriverDevice, _ active: Bool) {
    if let pluginId = self.pluginId {
      var mSelector: AudioObjectPropertySelector = getPropertySelectorFromString(getDeviceIsActiveProperty(device).rawValue)
      var address = AudioObjectPropertyAddress(
        mSelector: mSelector,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster
      )
      
      var data: CFBoolean = active.cfBooleanValue
      let size: UInt32 = UInt32(MemoryLayout<CFBoolean>.size)
      
      checkErr(AudioObjectSetPropertyData(pluginId, &address, 0, nil, size, &data))
    }
  }
  
  
  private static func getDeviceIsActiveProperty (_ device: DriverDevice) -> DriverDeviceIsActiveProperty {
    switch device {
    case .passthrough: return .passthrough
    case .ui: return .ui
    case .null: return .null
    }
  }
  
  private static func getPropertySelectorFromString (_ str: String) -> AudioObjectPropertySelector {
    return AudioObjectPropertySelector(UInt32.init(from: str.byteArray))
  }
  
  static var hasLatency: Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: getPropertySelectorFromString(CustomProperties.kAudioDeviceCustomPropertyLatency.rawValue),
      mScope: kAudioObjectPropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMaster
    )
    Console.log(CustomProperties.kAudioDeviceCustomPropertyLatency.rawValue, address.mSelector)
    return AudioObjectHasProperty(Driver.device!.id, &address)
  }
  static var latency: UInt32 {
    get {
      return Driver.device!.latency(direction: .playback)!
    }
    set {
      var address = AudioObjectPropertyAddress(
        mSelector: getPropertySelectorFromString(CustomProperties.kAudioDeviceCustomPropertyLatency.rawValue),
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster
      )
      
      let size: UInt32 = UInt32(MemoryLayout<CFNumber>.size)
      
      var newLatency = newValue
      var latency: CFNumber = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &newLatency)
      
      checkErr(AudioObjectSetPropertyData(Driver.device!.id, &address, 0, nil, size, &latency))
    }
  }
  
  static var safetyOffset: UInt32 {
    get {
      return Driver.device!.safetyOffset(direction: .playback)!
    }
    set {
      var address = AudioObjectPropertyAddress(
        mSelector: getPropertySelectorFromString(CustomProperties.kAudioDeviceCustomPropertySafetyOffset.rawValue),
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster
      )
      
      let size: UInt32 = UInt32(MemoryLayout<CFNumber>.size)
      
      var newSafetyOffset = newValue
      var safetyOffset: CFNumber = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &newSafetyOffset)
      
      checkErr(AudioObjectSetPropertyData(Driver.device!.id, &address, 0, nil, size, &safetyOffset))
    }
  }
  
  static var shown: Bool {
    get {
      if Driver.device == nil { return false }
      var address = AudioObjectPropertyAddress(
        mSelector: getPropertySelectorFromString(CustomProperties.kAudioDeviceCustomPropertyShown.rawValue),
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster
      )
      
      var size: UInt32 = UInt32(MemoryLayout<CFBoolean>.size)
      
      var shownBool = kCFBooleanFalse
      
      checkErr(AudioObjectGetPropertyData(Driver.device!.id, &address, 0, nil, &size, &shownBool))
      return CFBooleanGetValue(shownBool!)
    }
    set {
      if Driver.device == nil { return }

      var address = AudioObjectPropertyAddress(
        mSelector: getPropertySelectorFromString(CustomProperties.kAudioDeviceCustomPropertyShown.rawValue),
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster
      )
      
      let size: UInt32 = UInt32(MemoryLayout<CFBoolean>.size)
      var shownBool: CFBoolean = newValue.cfBooleanValue
      
      checkErr(AudioObjectSetPropertyData(Driver.device!.id, &address, 0, nil, size, &shownBool))
    }
  }
  
  static var installedVersion: String? {
    if Driver.device == nil { return nil }
    var address = AudioObjectPropertyAddress(
      mSelector: getPropertySelectorFromString(CustomProperties.kAudioDeviceCustomPropertyVersion.rawValue),
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    
    var size: UInt32 = UInt32(MemoryLayout<CFString>.size)
    
    var version: CFString? = nil
    
    checkErr(AudioObjectGetPropertyData(Driver.device!.id, &address, 0, nil, &size, &version))
    return version as String?
  }
  
  static var isMismatched: Bool {
    return bundledVersion != installedVersion
  }
  
  static var hidden: Bool {
    get { return !shown }
    set { shown = !newValue }
  }
  
  static var device: AudioDevice? {
    return AudioDevice.lookup(by: Constants.PASSTHROUGH_DEVICE_UID)
  }
  
  static func install (started: (() -> Void)? = nil, _ finished: @escaping (Bool) -> Void) {
    Script.sudo("install_driver", started: started, { success in
      finished(success)
    })
  }
  
  static func uninstall (started: (() -> Void)? = nil, _ finished: @escaping (Bool) -> Void) {
    Script.sudo("uninstall_driver", started: started, { success in
      finished(success)
    })
  }
  
}

