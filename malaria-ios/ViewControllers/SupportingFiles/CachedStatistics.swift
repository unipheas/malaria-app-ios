import Foundation
import UIKit

/// Responsible for keep a cache of the data and avoid repeating computations after every view controller transition
public class CachedStatistics : NSObject{
    /// Singleton
    static let sharedInstance = CachedStatistics()

    private var context: NSManagedObjectContext!
    
    var medicine: Medicine!
    var registriesManager: RegistriesManager!
    var statsManager: MedicineStats!
    
    var registries = [Registry]()

    //For PillStatsViewController
    var isMonthlyAdherenceDataUpdated = false
    var isGraphViewDataUpdated = false
    var isCalendarViewDataUpdated = false
    
    var tookMedicine: [NSDate: Bool] = [:]
    var monthAdhrence = [(NSDate, Float)]()
    var adherencesPerDay = [(NSDate, Float)]()
    
    //For dailyStats
    var isDailyStatsUpdated = false
    
    var lastMedicine: NSDate?
    var todaysPillStreak: Int = 0
    var todaysAdherence: Float = 0
    
    /// Init
    override public init(){
        super.init()
        NSNotificationEvents.ObserveDataUpdated(self, selector: "resetFlags")
        NSNotificationEvents.ObserveEnteredForeground(self, selector: "resetFlags")
    }
    
    deinit{
        NSNotificationEvents.UnregisterAll(self)
    }
    
    internal func resetFlags(){
        isMonthlyAdherenceDataUpdated = false
        isGraphViewDataUpdated = false
        isCalendarViewDataUpdated = false
        isDailyStatsUpdated = false
    }
    
    /// Call this to refresh the context. Don't forget to call desired methods to keep internal cache updated
    public func refreshContext(){
        self.context = CoreDataHelper.sharedInstance.createBackgroundContext()!
        
        medicine = MedicineManager(context: context).getCurrentMedicine()
        registriesManager = medicine.registriesManager
        statsManager = medicine.stats
    }
    
    /// Updates internal cache
    public func setupBeforeCaching() {
        registries = registriesManager.getRegistries(mostRecentFirst: false)
    }
}

extension CachedStatistics {
    /// Retrieves daily stats
    ///
    /// :param: `() -> ()`: Completition handler to be executed in the UI thread
    public func retrieveDailyStats(completition: () -> ()){
        lastMedicine = nil
        todaysPillStreak = 0
        todaysAdherence = 0
        
        Logger.Info("retrieveingDailyStats")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            self.todaysAdherence = self.statsManager.pillAdherence(date2: NSDate(), registries: self.registries) * 100
            
            let mostRecentFirst = self.registries.reverse()
            self.lastMedicine = self.registriesManager.lastPillDate(registries: mostRecentFirst)
            self.todaysPillStreak = self.statsManager.pillStreak(date2: NSDate(), registries: mostRecentFirst)
            
            self.isDailyStatsUpdated = true
            
            //update UI when finished
            dispatch_async(dispatch_get_main_queue(), completition)
        })
        
    }
    
    /// Retrieves month adherece
    ///
    /// :param: `NSDate`: Desired month
    /// :param: `() -> ()`: Completition handler to be executed in the UI thread
    public func retrieveMonthsData(numberMonths: Int, completition : () -> ()) {
        monthAdhrence.removeAll()
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            let today = NSDate()
            for i in 0...(numberMonths - 1) {
                let month = today - i.month
                let adherence = self.statsManager.monthAdherence(month, registries: self.registries)
                self.monthAdhrence.append((month, adherence * 100))
            }
            
            self.isMonthlyAdherenceDataUpdated = true
            
            //update UI when finished
            dispatch_async(dispatch_get_main_queue(), completition)
        })
    }
    
    /// Retrieves took medicine stats. Useful in a calendar view
    public func retrieveTookMedicineStats(){
        
        tookMedicine.removeAll()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            let entriesReversed = self.registries.reverse() //most recent first
            
            if !entriesReversed.isEmpty {
                let oldestDate = entriesReversed.last!.date.startOfDay
                let numDays = (NSDate() - oldestDate) + 1 //include today
                if numDays == 0 {
                    return
                }
                for i in 0...(numDays - 1) {
                    let day = oldestDate + i.day
                    self.tookMedicine[day] = self.registriesManager.tookMedicine(day, registries: entriesReversed) != nil
                }
            }
            
            self.isCalendarViewDataUpdated = true
        })
    }

    /// Update took medicine stats and calls the progress to update any information in the UI
    ///
    /// :param: `NSDate`: The day to be updated
    /// :param: `() -> ()`: Progress handler to be executed in the UI thread
    public func updateTookMedicineStats(at: NSDate, progress: (day: NSDate, remove: Bool) -> ()){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            
            self.refreshContext()
            self.setupBeforeCaching()
            
            let d1 = at - (self.medicine.interval - 1).day
            let d2 = at + (self.medicine.interval - 1).day
            
            let entriesReversed = self.registries.reverse() //most recentFirst
            if !entriesReversed.isEmpty {
                let numDays = d2 - d1 + 1 //include d2
                if numDays == 0 {
                    return
                }
                for i in 0...(numDays - 1) {
                    let day = (d1 + i.day).startOfDay
                    self.tookMedicine[day] = self.registriesManager.tookMedicine(day, registries: entriesReversed) != nil
                }
                
                let oldestEntry = entriesReversed.last!.date
                
                //Removing previous suplementary views. Happens when the oldest entry data changes
                let startDelete = oldestEntry - self.medicine.interval.day
                for i in 0...self.medicine.interval {
                    dispatch_async(dispatch_get_main_queue(), {
                        progress(day: (startDelete + i.day).startOfDay, remove: true)
                    })
                }
                
                let numEntries = NSDate() - oldestEntry + 1
                for i in 0...(numEntries - 1){
                    dispatch_async(dispatch_get_main_queue(), {
                        progress(day: (oldestEntry + i.day).startOfDay, remove: false)
                    })
                }
            }
        })
    }
    
    /// Retrieves cached statistics for the graph
    ///
    /// :param: `(progress: Float) -> ()`: Progress handler to be executed in the UI thread. Usually a progress bar
    /// :param: `() -> ()`: Completition handler to be executed in the UI after finishing processing
    public func retrieveCachedStatistics(progress: (progress: Float) -> (), completition : () -> ()) {
        adherencesPerDay.removeAll()
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            let today = NSDate()
            var entries = self.registries
            
            if !entries.isEmpty {
                let oldestDate = entries[0].date
                let numDays = (today - oldestDate) + 1 //include today
                
                self.adherencesPerDay = [(NSDate,Float)](count: numDays, repeatedValue: (today, 0))
                
                if numDays == 0 {
                    return
                }
                for v in 0...(numDays - 1) {
                    let index = (numDays - 1) - v
                    
                    let day = today - v.day
                    
                    let adherence = self.statsManager.pillAdherence(date1: oldestDate, date2: day, registries: entries)
                    self.adherencesPerDay[index] = (day, adherence * 100)
                    
                    //updating array from last index to first Index
                    for j in 0...(entries.count - 1) {
                        let posDate = entries.count - 1 - j
                        if entries[posDate].date.sameDayAs(day){
                            entries.removeAtIndex(posDate)
                            break
                        }
                    }
                    
                    //Update progress bar
                    dispatch_async(dispatch_get_main_queue(), {
                        progress(progress: 100*Float(numDays - (numDays - v))/Float(numDays))
                    })
                }
                
                self.isGraphViewDataUpdated = true
            }
            
            //update UI when finished
            dispatch_async(dispatch_get_main_queue(), completition)
        })
    }

}