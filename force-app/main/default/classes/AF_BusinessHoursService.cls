public class AF_BusinessHoursService {
    public class Request {
        @InvocableVariable(required=true)
        public String businessHoursName;
        @InvocableVariable(required=true)
        public DateTime startDateTime;
        @InvocableVariable(required=true)
        public Long durationMillis;
    }

    public class Response {
        @InvocableVariable
        public DateTime resultDateTime;
    }

    @InvocableMethod(label='Add Business Hours Duration' description='Adds a duration to a start date/time respecting the named Business Hours record (skips non-working time). Falls back to plain calendar-time addition if the named Business Hours record is not found.')
    public static List<Response> addBusinessHoursDuration(List<Request> requests) {
        Set<String> names = new Set<String>();
        for (Request req : requests) {
            names.add(req.businessHoursName);
        }

        Map<String, Id> nameToId = new Map<String, Id>();
        for (BusinessHours bh : [SELECT Id, Name FROM BusinessHours WHERE Name IN :names]) {
            nameToId.put(bh.Name, bh.Id);
        }

        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            Id bhId = nameToId.get(req.businessHoursName);
            if (bhId != null) {
                res.resultDateTime = BusinessHours.add(bhId, req.startDateTime, req.durationMillis);
            } else {
                res.resultDateTime = req.startDateTime.addSeconds(Integer.valueOf(req.durationMillis / 1000));
            }
            responses.add(res);
        }
        return responses;
    }
}