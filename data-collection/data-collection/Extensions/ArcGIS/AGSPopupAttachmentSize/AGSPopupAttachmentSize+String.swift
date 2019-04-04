//// Copyright 2019 Esri
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArcGIS

extension AGSPopupAttachmentSize {
    
    var actualSize: CGSize {
        switch self {
        case .actual:
            return .zero
        case .small:
            return CGSize(width: 240, height: 320)
        case .medium:
            return CGSize(width: 480, height: 640)
        case .large:
            return CGSize(width: 960, height: 1280)
        case .extraLarge:
            return CGSize(width: 1126, height: 1500)
        }
    }
    
    var actualSizeScaled: CGSize {
        let size = actualSize
        let scale = UIScreen.main.scale
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
    
    var actualSizeTitle: String {
        return titleFor(size: actualSize)
    }
    
    var actualSizeScaledTitle: String {
        return titleFor(size: actualSizeScaled)
    }
    
    private func titleFor(size: CGSize) -> String {
        
        let width = Int(size.width)
        let height = Int(size.height)
        
        switch self {
        case .small:
            return "Small \(width)x\(height)"
        case .medium:
            return "Medium \(width)x\(height)"
        case .large:
            return "Large \(width)x\(height)"
        case .extraLarge:
            return "Extra Large \(width)x\(height)"
        case .actual:
            return "Actual Size (full resolution)"
        }
    }
}
