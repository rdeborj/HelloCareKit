//
//  TabBarController.swift
//  HelloCareKit
//
//  Created by Richard de Borja on 2019-01-28.
//  Copyright © 2019 The University Health Network. All rights reserved.
//

import UIKit
import CareKit

class TabBarController: UITabBarController {

    lazy var carePlanStore: OCKCarePlanStore = {
        let fileManager = FileManager.default
//        addActivities()
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let url = urls[0].appendingPathComponent("carePlanStore")
        
        if !fileManager.fileExists(atPath: url.path) {
            try! fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        let store = OCKCarePlanStore(persistenceDirectoryURL: url)
        store.delegate = self
        return store

//        return OCKCarePlanStore(persistenceDirectoryURL: url)
    }()
    
    let activityStartDate = DateComponents(year: 2019, month: 1, day: 1)
    let calendar = Calendar(identifier: .gregorian)
    var insights: OCKInsightsViewController!
    var insightItems = [OCKInsightItem]() {
        didSet {
            insights.items = insightItems
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addActivities()
        let careCard = OCKCareCardViewController(carePlanStore: carePlanStore)
        careCard.title = "Care"
        let symptomTracker = OCKSymptomTrackerViewController(carePlanStore: carePlanStore)
        symptomTracker.title = "Measurements"
        
        symptomTracker.delegate = self
        
        insights = OCKInsightsViewController(insightItems: insightItems)
        insights.title = "Insights"
        updateInsights()
        
        viewControllers = [
            UINavigationController(rootViewController: careCard),
            UINavigationController(rootViewController: insights),
            UINavigationController(rootViewController: symptomTracker)
        ]
    }
    
    func interventions() -> [OCKCarePlanActivity] {
        let waterSchedule = OCKCareSchedule.dailySchedule(withStartDate: activityStartDate, occurrencesPerDay: 8)
        let waterIntervention = OCKCarePlanActivity.intervention(withIdentifier: "water", groupIdentifier: nil, title: "Water", text: "Number of glasses", tintColor: .blue, instructions: nil, imageURL: nil, schedule: waterSchedule, userInfo: nil, optional: false)
        let exerciseSchedule = OCKCareSchedule.dailySchedule(withStartDate: activityStartDate, occurrencesPerDay: 1, daysToSkip: 1, endDate: nil)
        let exerciseIntervention = OCKCarePlanActivity.intervention(withIdentifier: "exercise", groupIdentifier: nil, title: "Exercise", text: "30 min", tintColor: .orange, instructions: nil, imageURL: nil, schedule: exerciseSchedule, userInfo: nil, optional: false)
        
        return [waterIntervention, exerciseIntervention]
    }

    func assessments() -> [OCKCarePlanActivity] {
        let oncePerDaySchedule = OCKCareSchedule.dailySchedule(withStartDate: activityStartDate, occurrencesPerDay: 1)
        let sleepAssessment = OCKCarePlanActivity.assessment(withIdentifier: "sleep", groupIdentifier: nil, title: "Sleep", text: "How many hours did you sleep last night?", tintColor: .purple, resultResettable: true, schedule: oncePerDaySchedule, userInfo: nil, optional: false)
        let weightAssessment = OCKCarePlanActivity.assessment(withIdentifier: "weight", groupIdentifier: nil, title: "Weight", text: "How much do you weight?", tintColor: .brown, resultResettable: true, schedule: oncePerDaySchedule, userInfo: nil, optional: false)
        return [sleepAssessment, weightAssessment]
    }
    
    func addActivities() {
        carePlanStore.activities { [unowned self] (_, activities, error) in
            if let error = error {
                print(error.localizedDescription)
            }
            guard activities.count == 0 else { return }
            
            for activity in self.interventions() + self.assessments() {
                self.carePlanStore.add(activity) { (_, error) in
                    guard let error = error else { return }
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    func updateInsights() {
        
    }
}

extension TabBarController: OCKSymptomTrackerViewControllerDelegate {
    func symptomTrackerViewController(_ viewController: OCKSymptomTrackerViewController, didSelectRowWithAssessmentEvent assessmentEvent: OCKCarePlanEvent) {
        
        let alert: UIAlertController
        if assessmentEvent.activity.identifier == "sleep" {
            alert = sleepAlert(event: assessmentEvent)
        } else if assessmentEvent.activity.identifier == "weight" {
            alert = weightAlert(event: assessmentEvent)
        } else {
            return
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    func sleepAlert(event: OCKCarePlanEvent) -> UIAlertController {
        let alert = UIAlertController(title: "Sleep", message: "How many hours did you sleep last night?", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.keyboardType = .numberPad
        }
        
        let doneAction = UIAlertAction(title: "Done", style: .default) { [unowned self] _ in
            let sleepField = alert.textFields![0]
            let result = OCKCarePlanEventResult(valueString: sleepField.text!, unitString: "hours", userInfo: nil)
            self.carePlanStore.update(event, with: result, state: .completed) { (_, _, error) in
                if let error = error {
                    print(error.localizedDescription)
                }
            }
        }
        alert.addAction(doneAction)
        return alert
    }
    
    func weightAlert(event: OCKCarePlanEvent) -> UIAlertController {
        let alert = UIAlertController(title: "Weight", message: "How much do you weigh (in kilograms)?", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.keyboardType = .numberPad
        }
        let doneAction = UIAlertAction(title: "Done", style: .default) { [unowned self] _ in
            let weightField = alert.textFields![0]
            let result = OCKCarePlanEventResult(valueString: weightField.text!, unitString: "kg", userInfo: nil)
            self.carePlanStore.update(event, with: result, state: .completed) { (_, _, error) in
                if let error = error {
                    print(error.localizedDescription)
                }
            }
        }
        alert.addAction(doneAction)
        return alert
    }
}

extension TabBarController: OCKCarePlanStoreDelegate {
    func carePlanStore(_ store: OCKCarePlanStore, didReceiveUpdateOf event: OCKCarePlanEvent) {
        updateInsights()
    }
}
