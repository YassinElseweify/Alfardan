public class QueryContextTags {
    @InvocableMethod(label='QueryContextTags' description='Query Tags via apex')
    public static List<ContextResponse> queryTags(List<ContextRequest> requestList) {
        Context.IndustriesContext industriesContexts = new Context.IndustriesContext();
        Map<String, Object> input = new Map<String, Object>();
        List<String> tag = new List<String>();
        tag.add(requestList[0].tagName);
        input.put('contextId', requestList[0].contextId);
        input.put('tags', tag);
        Map<String, Object> output =  new Map<String, Object>();
        List<ContextResponse> responseList = new List<ContextResponse>();
        ContextResponse response = new ContextResponse();
      
            output =industriesContexts.queryTags(input); 
            Map<String, Object> queryresult = (Map<String, Object>)output.get('queryResult');
            List<Object> contextTagDataRepresentations= (List<Object>)queryresult.get(requestList[0].tagName);
            Map<String,Object> contextTagDataRepresentation = (Map<String,Object>)contextTagDataRepresentations.get(0);
            response.dataPath = (List<String>)contextTagDataRepresentation.get('dataPath');
            response.tagValue = (String) contextTagDataRepresentation.get('tagValue');
            responseList.add(response);
                   
        return responseList;      
    }
   
    public class ContextRequest{
        @InvocableVariable(required=true)
        public String contextId;
       
        @InvocableVariable(required=true)
        public String tagName;
    }
   
    public class ContextResponse{
        @InvocableVariable(required=true)
        public List<String> dataPath;
       
        @InvocableVariable(required=true)
        public String tagValue;
    }
}