@isTest
public with sharing class ddHttpMockResponse implements HttpCalloutMock {

    private String mode;

    public ddHttpMockResponse(String mode) {
        this.mode = mode;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        if (this.mode == 'object') {
            res.setBody('{"size":1,"totalSize":1,"done":true,"queryLocator":null,"entityTypeName":"CustomObject","records":[{"attributes":{"type":"CustomObject","url":"/services/data/v51.0/tooling/sobjects/CustomObject/01I5e000000UEqcEAG"},"Description":"This is a test description.","CreatedDate":"2021-04-25T12:46:01.000+0000","CreatedById":"0055e000000yhkWAAQ"}]}');
        }
        res.setStatusCode(200);
        return res;
    }
}
