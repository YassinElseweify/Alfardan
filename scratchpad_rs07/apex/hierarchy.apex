// QA RS-07 test hierarchy, built to match the DoA matrix roles so escalation is testable.
// ORIGINAL VALUES (restore after testing):
//   Sales Representative 005a3001tN36pJcAQI -> 005a3001tMuiXFcAQM (Alfardan Salesforce)
//   Sales Manager        005a3001tN3B1SeAQK -> 005a3001tMuiXFcAQM (Alfardan Salesforce)
//   Showroom Manager     005a3001tN4fKfMAQU -> null
//   QA Test Admin        005a3001tN4Bxe8AQC -> null
//   Arcsen Alfardan      005a3001vLvmFZ6AQM -> null
update new List<User>{
  new User(Id='005a3001tN36pJcAQI', ManagerId='005a3001tN3B1SeAQK'), // Rep      -> Sales Manager   (Tier 1)
  new User(Id='005a3001tN3B1SeAQK', ManagerId='005a3001tN4fKfMAQU'), // SalesMgr -> Showroom Mgr    (Tier 2)
  new User(Id='005a3001tN4fKfMAQU', ManagerId='005a3001tN4Bxe8AQC'), // ShowMgr  -> QA Test Admin   (Tier 3 / GM)
  new User(Id='005a3001tN4Bxe8AQC', ManagerId='005a3001vLvmFZ6AQM')  // QATAdmin -> Arcsen Alfardan (Tier 4 / CEO)
};
for (User u : [SELECT Id, Name, Manager.Name FROM User WHERE Id IN
    ('005a3001tN36pJcAQI','005a3001tN3B1SeAQK','005a3001tN4fKfMAQU','005a3001tN4Bxe8AQC')])
    System.debug('CHAIN: ' + u.Name + ' -> ' + u.Manager.Name);
