// Restore the manager hierarchy to its as-found state so the org reflects real config.
update new List<User>{
  new User(Id='005a3001tN36pJcAQI', ManagerId='005a3001tMuiXFcAQM'), // Sales Rep -> Alfardan Salesforce
  new User(Id='005a3001tN3B1SeAQK', ManagerId='005a3001tMuiXFcAQM'), // Sales Mgr -> Alfardan Salesforce
  new User(Id='005a3001tN4fKfMAQU', ManagerId=null),                 // Showroom Manager -> none
  new User(Id='005a3001tN4Bxe8AQC', ManagerId=null)                  // QA Test Admin -> none
};
for (User u : [SELECT Id, Name, Manager.Name FROM User WHERE Id IN
    ('005a3001tN36pJcAQI','005a3001tN3B1SeAQK','005a3001tN4fKfMAQU','005a3001tN4Bxe8AQC')])
    System.debug('RESTORED: ' + u.Name + ' -> ' + u.Manager.Name);
