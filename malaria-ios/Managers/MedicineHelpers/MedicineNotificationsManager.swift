import Foundation
import UIKit

public class MedicineNotificationsManager : NotificationManager{
    override var category: String { get{ return "PillReminder" } }
    override var alertBody: String { get{ return "Don't forget to take \(MedicineManager(context: context).getCurrentMedicine()!.name)" } }
    override var alertAction: String { get{ return "Take pill"} }
    
    let medicine: Medicine
    
    init(context: NSManagedObjectContext, medicine: Medicine){
        self.medicine = medicine
        super.init(context: context)
    }
    
    public override func scheduleNotification(fireTime: NSDate){
        super.scheduleNotification(fireTime)
        
        if(medicine.notificationTime != fireTime){
            medicine.notificationTime = fireTime
            CoreDataHelper.sharedInstance.saveContext(self.context)
        }
    }
    
    public override func unsheduleNotification(){
        super.unsheduleNotification()
        
        medicine.notificationTime = nil
        CoreDataHelper.sharedInstance.saveContext(self.context)
    }

    public func reshedule(){
        if var nextTime = medicine.notificationTime{
            nextTime += medicine.isDaily() ? 1.day : 7.day
            medicine.notificationTime = nextTime
            
            Logger.Info("Resheduling to " + nextTime.formatWith("dd-MMMM-yyyy hh:mm"))
            
            unsheduleNotification()
            scheduleNotification(nextTime)
            
            return
        }
        
        if medicine.isCurrent{
            Logger.Error("Error: there should be already a fire date")
        }
    }
    
    /// Checks if a week went by without a entry (only valid for weekly pills)
    ///
    /// :param: `NSDate optional`: Current date. (by default is the most current one)
    /// :returns: `Bool`: true if should, false if not
    public func checkIfShouldReset(currentDate: NSDate = NSDate()) -> Bool{
        if medicine.isDaily(){
            Logger.Warn("checkIfShouldReset only valid for weekly pills")
            return false
        }
        
        if let mostRecent = medicine.registriesManager(context).mostRecentEntry(){
            //get ellaped days
            return (currentDate - mostRecent.date) >= 7
        }
        
        Logger.Warn("There are no entries yet. Returning false")
        return false
    }
}