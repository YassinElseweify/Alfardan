// DoA-aligned approval chain for ALF-RS-07.
// Each approval step walks one level UP the Manager field, so the chain must be:
//   Tier 1 step -> Rep's manager          = Showroom Manager Automobiles
//   Tier 2 step -> that person's manager  = Sales Manager
//   Tier 3 step (General Manager)         = Arcsen Alfardan      (System Administrator)
//   Tier 4 step (CEO)                     = QA Test Admin        (System Administrator)
// Tiers 3 and 4 are System Admins because no General Manager or CEO user exists
// in the org and all 10 Salesforce licences are consumed.
update new List<User>{
  new User(Id='005a3001tN36pJcAQI', ManagerId='005a3001tN4fKfMAQU'), // Sales Rep       -> Showroom Manager
  new User(Id='005a3001tN4fKfMAQU', ManagerId='005a3001tN3B1SeAQK'), // Showroom Mgr    -> Sales Manager
  new User(Id='005a3001tN3B1SeAQK', ManagerId='005a3001vLvmFZ6AQM'), // Sales Manager   -> Arcsen (GM)
  new User(Id='005a3001vLvmFZ6AQM', ManagerId='005a3001tN4Bxe8AQC'), // Arcsen (GM)     -> QA Test Admin (CEO)
  new User(Id='005a3001tN4Bxe8AQC', ManagerId=null)                  // QA Test Admin   -> top of chain
};
for (User u : [SELECT Name, Manager.Name FROM User WHERE Id IN
   ('005a3001tN36pJcAQI','005a3001tN4fKfMAQU','005a3001tN3B1SeAQK','005a3001vLvmFZ6AQM','005a3001tN4Bxe8AQC')])
   System.debug('CHAIN: ' + u.Name + '  ->  ' + u.Manager.Name);
