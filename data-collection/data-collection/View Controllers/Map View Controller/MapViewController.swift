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

import UIKit
import ArcGIS
import ArcGISToolkit

class MapViewController: UIViewController {
    
    enum MapViewMode: Equatable {
        case defaultView
        case disabled
        case selectedFeature(visible: Bool)
        case selectingFeature
        case offlineMask
    }
    
    @IBOutlet weak var mapView: AGSMapView!
    @IBOutlet weak var popupsContainerView: UIView!
    @IBOutlet weak var addPopupRelatedRecordButton: UIButton!
    @IBOutlet weak var selectView: UIView!
    @IBOutlet weak var pinDropView: PinDropView!
    weak var activityBarView: ActivityBarView!
    @IBOutlet weak var slideNotificationView: SlideNotificationView!
    @IBOutlet weak var compassView: CompassView!
    @IBOutlet weak var reloadMapButton: UIButton!
    
    @IBOutlet weak var relatedRecordHeaderLabel: UILabel!
    @IBOutlet weak var relatedRecordSubheaderLabel: UILabel!
    @IBOutlet weak var relatedRecordsNLabel: UILabel!
    
    @IBOutlet var selectViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var selectViewHeaderLabel: UILabel!
    @IBOutlet weak var selectViewSubheaderLabel: UILabel!
    
    var maskViewController: MaskViewController!
    @IBOutlet weak var maskViewContainer: UIView!
    
    var featureDetailViewBottomConstraint: NSLayoutConstraint!
    
    var visibleAreaObserver: NSKeyValueObservation?

    var identifyOperation: AGSCancelable?
    
    var extrasNavigationController: UINavigationController?
    var layerContentsViewController: LayerContentsViewController?
//    var floatingPanelController: FloatingPanelController? {
//        willSet {
//            // Dismiss the existing floating panel if we're showing one.
//            if let exsistingFloatingPanel = floatingPanelController {
//                dismissFloatingPanel(exsistingFloatingPanel)
//            }
//        }
//    }
    
    //TODO: create `instantiate()` like in FloatingPanelController
    lazy var identifyResultsViewController: IdentifyResultsViewController = {
        // Get the bundle and then the storyboard for the IdentifyResultsViewController.
        let bundle = Bundle(for: IdentifyResultsViewController.self)
        let storyboard = UIStoryboard(name: "IdentifyResultsViewController", bundle: bundle)
        
        // Create the identifyResultsViewController from the storyboard.
        let vc = storyboard.instantiateInitialViewController() as? IdentifyResultsViewController
        return vc ?? IdentifyResultsViewController()
    }()

    var mapViewMode: MapViewMode = .defaultView {
        didSet {
            adjustForMapViewMode(from: oldValue, to: mapViewMode)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Assign the map view touch delegate and other configurations.
        setupMapView()
        
        // Builds and constrains the activity view to the map view.
        setupActivityBarView()

        // Set initial map view mode.
        adjustForMapViewMode(from: nil, to: mapViewMode)
        
        // Associate the compass view to the map view.
        compassView.mapView = mapView
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adjustForLocationAuthorizationStatus),
            name: .locationAuthorizationDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adjustForWorkMode),
            name: .workModeDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adjustForPortal),
            name: .portalDidChange,
            object: nil
        )
                
        // Adjust location display for app location authorization status. If location authorized is undetermined, this will prompt the user for authorization.
        adjustForLocationAuthorizationStatus()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refreshCurrentPopup()
    }
        
    // MARK:- Extras
    
    @IBOutlet weak var extrasButton: UIBarButtonItem!
    
    @IBAction func userRequestsExtras(_ sender: Any) {
        userRequestsExtras(sender as? UIBarButtonItem)
    }
    
    // MARK:- Location Display
    
    @IBOutlet weak var zoomButton: UIBarButtonItem!
    
    @IBAction func userRequestsZoomLocationDisplay(_ sender: Any) {
        userRequestsZoomOnUserLocation()
    }
    
    // MARK:- Add Feature
    
    @IBOutlet weak var addFeatureButton: UIBarButtonItem!
    
    @IBAction func userRequestsAddFeature(_ sender: Any) {
        userRequestsAddNewFeature(sender as? UIBarButtonItem)
    }
    
    // MARK:- Reload
    
    @IBAction func userRequestsReloadMap(_ sender: Any) {
        loadMapViewMap()
    }
    
    // MARK:- Related Record
    
    @IBAction func userRequestsAddNewRelatedRecord(_ sender: Any) {
        
        assert(currentPopupManager != nil, "This function should not be reached if a popup is not currently selected.")
        
        guard let manager = currentPopupManager, let relationships = manager.richPopup.relationships, let relationship = relationships.oneToMany.first else {
            showError(UnknownError())
            return
        }

        let relatedManager: RichPopupManager
        
        do {
            relatedManager = try manager.buildRichPopupManagerForNewOneToManyRecord(for: relationship)
        }
        catch {
            showError(error)
            return
        }

        SVProgressHUD.show(withStatus: String(format: "Creating new %@.", (relatedManager.title ?? "related record")))

        relationships.load { [weak self] (error) in

            SVProgressHUD.dismiss()

            guard let self = self else { return }

            if let error = error {
                self.showError(error)
                return
            }

            EphemeralCache.shared.setObject(
                relatedManager,
                forKey: .newRelatedRecord
            )

            self.performSegue(withIdentifier: "modallyPresentRelatedRecordsPopupViewController", sender: nil)
        }
    }
    
    // MARK: Current Pop-Up
    
    private(set) var currentPopupManager: RichPopupManager?
    private(set) var selectedPopups = [RichPopup]()

    func setSelectedPopups(popups: [RichPopup]) {
        // Clear existing selection
        (currentPopupManager?.popup.feature?.featureTable?.layer as? AGSFeatureLayer)?.clearSelection()
        selectedPopups = popups
    }

    func setCurrentPopup(popup: RichPopup) {
        
        // Clear existing selection
        (currentPopupManager?.popup.feature?.featureTable?.layer as? AGSFeatureLayer)?.clearSelection()
        
        // Build new rich popup manager.
        currentPopupManager = RichPopupManager(richPopup: popup)
    }
    
    func clearCurrentPopup() {
        
        // Clear existing selection.
        (currentPopupManager?.popup.feature?.featureTable?.layer as? AGSFeatureLayer)?.clearSelection()
        
        // Nullify current popup manager.
        currentPopupManager = nil
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {

        if identifier == "modallyPresentRelatedRecordsPopupViewController" {
            return currentPopupManager != nil
        }
        
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if let destination = segue.navigationDestination as? RichPopupViewController {
            
            if let newPopup = EphemeralCache.shared.object(forKey: .newSpatialFeature) as? RichPopup {
                setCurrentPopup(popup: newPopup)
                destination.popupManager = currentPopupManager!
                destination.setEditing(true, animated: false)
                mapViewMode = .selectedFeature(visible: false)
            }
            else if let popupManager = EphemeralCache.shared.object(forKey: .newRelatedRecord) as? RichPopupManager {
                destination.popupManager = popupManager
                destination.setEditing(true, animated: false)
                destination.shouldLoadRichPopupRelatedRecords = false
            }
            else if let currentPopupManager = currentPopupManager {
                destination.popupManager = currentPopupManager
            }
            else {
                assertionFailure("A rich popup view controller should not present if any of the above scenarios are not met.")
            }
        }
        else if let destination = segue.destination as? MaskViewController {
            maskViewController = destination
        }
        else if let destination = segue.navigationDestination as? ProfileViewController {
            destination.delegate = self
        }
        else if let destination = segue.destination as? JobStatusViewController {
            destination.job = EphemeralCache.shared.object(forKey: "OfflineMapJobID") as? OfflineMapJobManager.Job
        }
    }
    
    // MARK:- Work Mode
    
    @objc func adjustForWorkMode() {
        let color: UIColor
        if case .online = appContext.workMode {
            color = .primary
            slideNotificationView.messageBackgroundColor = color.lighter
        }
        else { // .offline = appContext.workMode
            color = .offline
            slideNotificationView.messageBackgroundColor = color.darker
        }
        activityBarView.colors = (color.lighter, color.darker)
        
        adjustForCurrentMap()
    }
    
    // MARK:- Portal
    
    @objc func adjustForPortal() {
        if let error = appContext.portalSession.error {
            showError(error)
        }
    }
}

extension String {
    static let newSpatialFeature = "MapViewController.newFeature.spatial"
    static let newNonSpatialFeature = "MapViewController.newFeature.nonspatial"
    static let newRelatedRecord = "MapViewController.newRelatedRecord"
}

// MARK: MapViewController Identifyf extension
extension MapViewController {
    func userDidRequestPopupViewController(_ sender: Any) {
        guard case MapViewMode.selectedFeature(visible: true) = mapViewMode, currentPopupManager != nil else { return }
        mapViewMode = .selectedFeature(visible: true)
        performSegue(withIdentifier: "modallyPresentRelatedRecordsPopupViewController", sender: nil)
    }
}
