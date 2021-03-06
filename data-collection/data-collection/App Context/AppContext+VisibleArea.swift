//// Copyright 2018 Esri
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

import Foundation
import ArcGIS

extension AppContext {
    
    private var visibleAreaDefaultsKey: String { return "VisibleAreaDefaultsKey.\(String.webMapItemID)" }
    
    /// The shared visible area `AGSViewpoint`.
    ///
    /// This allows the app to restore the map view's current visible area from a previous session.
    ///
    /// - Note: The `AGSViewpoint` is serialized and stored in `UserDefaults`.
    var sharedVisibleArea: AGSViewpoint? {
        set {
            guard newValue?.targetGeometry != nil else {
                UserDefaults.standard.set((nil as Any?), forKey: visibleAreaDefaultsKey)
                return
            }
            
            UserDefaults.standard.setSerializable(newValue, forKey: visibleAreaDefaultsKey)
        }
        get {
            return UserDefaults.standard.getSerializable(forKey: visibleAreaDefaultsKey)
        }
    }
}
