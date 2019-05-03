// Function to automatically insert a link
// into the Turk landing page used to launch an experiment.
// The function is called by including the following snippet
// at the appropriate point in your page:
//
// <p>
//    This HIT takes place on an external website. A link to the
//    site will appear below once you have accepted this HIT.
//    Clicking on the link will open the external page in
//    a new browser tab. If at any time you no longer wish to participate,
//    simply close the browser tab and return the HIT.
// </p>
//
// <div id="experimentLink" style="display: inline; font-family: Verdana;">
//     <tt>
//         The external link cannot be shown because there is an error with Javascript
//         on your computer. To perform this HIT, you must have
//         Javascript and cookies enabled on your browser.
//     </tt>
// </div>
//
// <script src="https://myexperiment.appspot.com/js/turkGlue.js"></script>
// <script>
//   turkGlueFunction("https://myexperiment.appspot.com/","my1stParam=xxx&myNextParam=123");
// </script>
//
// After calling the function, the landing page will be updated so that
// the text of the <div id="experimentLink">...</div> is updated with
// the appropriate link (assuming that the Worker has accepted the HIT.
// The following parameters are prepended to the query parameter string
// you supply via queryParams (which must omit the leading "?", as in the
// above example):
//
// ?mtWorkerID=<worker id>&mtAssignemtnID=<assignment id>&mtHitId=<hit id>
//
//
function turkGlueFunction(url, queryParams)
{
    // Find the insertion point where we will insert the link
    var linkInsertionPoint = document.getElementById('experimentLink');

    //Get the query string from the URL for the Turk landing page
    var queryString = window.location.search.substring(1);
    var nameValuePairs = queryString.split("&");

    var workerId = "";
    var assignmentId = "";
    var hitId = "";

    // Search all parameters
    for (var i in nameValuePairs) {
        var nameValue = nameValuePairs[i].split("=");

        if (nameValue[0] == "workerId") {
            workerId = nameValue[1];
        }
        else if (nameValue[0] == "hitId") {
            hitId = nameValue[1];
        }
        else if (nameValue[0] == "assignmentId") {
            assignmentId = nameValue[1];
        }
    }

    if (workerId == "") {
        linkInsertionPoint.innerHTML = '<tt>The link to the external site used for this HIT will only appear if you accept the HIT.</tt>';
    }
    else {
        linkInsertionPoint.innerHTML = '<a target="_blank" href="' + url + '?mtWorkerId=' + workerId + '&mtHitId=' + hitId + '&mtAssignmentId=' + assignmentId + '&' + queryParams + '"><h1><span style="color: rgb(255, 0, 0);"><span style="font-family: Courier New;"><b>Click here to visit the external site used for this HIT!</b></span></span></h1></a>';
    }
}
