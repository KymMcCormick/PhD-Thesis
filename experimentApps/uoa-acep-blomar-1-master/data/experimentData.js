// The contents of this file must be valid javascript syntax
// i.e. need not be strict JSON) syntax

// The experiment currently has 7 conditions
// corresponding to lineup array size {2,..,8}.
//
// Typically, participants will be allocated to a condition
// selected at random (in a round-robin fashion).
//
// However, the "cond" request parameter can be used to
// hard-wire a specific target or lineup size in which case
//
// cond = <array size>
//
// e.g. cond=3

CONDITIONS = [
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8"
];

lineupSize = function(cond) {
    let s = cond.split("_");
    return parseInt(s[0]);
};

COMMON_LINEUP_DATA = {
    target: {id: "F68", image: "images/F68.JPG", video: "amyY2Gck-8I"},

    suspects: [
        //{id: "F2", image: "images/F2.JPG", video: "MISSING"},
        //{id: "F20", image: "images/F20.JPG", video: "OQ_-4voFB60"},
        //{id: "F23", image: "images/F23.JPG", video: "jqZImwmfPvI"},
        {id: "F34", image: "images/F34.JPG", video: "pS3LLcjT214"},
        {id: "F50", image: "images/F50.JPG", video: "" },

        {id: "F71", image: "images/F71.JPG", video: "37acYutPvg0"},
        //{id: "F73", image: "images/F73.JPG", video: "7rJW-AGmnFQ"},
        {id: "F88", image: "images/F88.JPG", video: "VKENCZZ-eH0"},
        //{id: "F99", image: "images/F99.JPG", video: "lI7YgHZ4XYM"},
        //{id: "F114", image: "images/F114.JPG", video: "jB9r1xv27hA"},
        //{id: "F119", image: "images/F119.JPG", video: "5JAY-tR7vjA"},
        //{id: "F132", image: "images/F132.JPG", video: "fabaRlWuo54"},
        {id: "F134", image: "images/F134.JPG", video: "BvbNBVEkG60"},
        {id: "F147", image: "images/F147.JPG", video: "Cqs6t2o2vE4"},
        //{id: "F154", image: "images/F154.JPG", video: "TtWemtgZgLs"},
        {id: "F176", image: "images/F176.JPG", video: "DW71Df7iFtg"},
        {id: "F177", image: "images/F177.JPG", video: "lut93__iLXQ"}
    ],

    distractors: [
        //{id: "F2", image: "images/F2.JPG", video: "MISSING"},
        //{id: "F20", image: "images/F20.JPG", video: "OQ_-4voFB60"},
        {id: "F23", image: "images/F23.JPG", video: "jqZImwmfPvI"},
        //{id: "F34", image: "images/F34.JPG", video: "pS3LLcjT214"},
        //{id: "F50", image: "images/F50.JPG", video: "" },

        //{id: "F71", image: "images/F71.JPG", video: "37acYutPvg0"},
        {id: "F73", image: "images/F73.JPG", video: "7rJW-AGmnFQ"},
        //{id: "F88", image: "images/F88.JPG", video: "VKENCZZ-eH0"},
        {id: "F99", image: "images/F99.JPG", video: "lI7YgHZ4XYM"},
        {id: "F114", image: "images/F114.JPG", video: "jB9r1xv27hA"},
        {id: "F119", image: "images/F119.JPG", video: "5JAY-tR7vjA"},
        {id: "F132", image: "images/F132.JPG", video: "fabaRlWuo54"},
        //{id: "F134", image: "images/F134.JPG", video: "BvbNBVEkG60"},
        //{id: "F147", image: "images/F147.JPG", video: "Cqs6t2o2vE4"},
        {id: "F154", image: "images/F154.JPG", video: "TtWemtgZgLs"},
        //{id: "F176", image: "images/F176.JPG", video: "DW71Df7iFtg"},
        //{id: "F177", image: "images/F177.JPG", video: "lut93__iLXQ"}
    ],

    // 2, 133
    // 2,34,50,68,71,73,88,114,132,133,134,147,176,177

};

STUDY_PHASE = {
    "phaseName": "Study",
    "templateId": "studyTrialTemplate",

    // "numBlocks" represents the number of blocks of trials
    // within the current phase. Currently only "1" is supported :)
    "numBlocks": 1,

    lineupData: COMMON_LINEUP_DATA,

    // "trials" is an array of objects, one per trial.
    "trials" : [{
        id: "S-1" // dummy trial data
    }]
};

TEST_PHASE = {
    "phaseName": "Test",
    "templateId": "testTrialTemplate",

    // "numBlocks" represents the number of blocks of trials
    // within the current phase. Currently only "1" is supported :)
    "numBlocks": 1,

    lineupData: COMMON_LINEUP_DATA,

    // "trials" is an array of objects, one per trial.
    // The full trial data will be generated dynamically.
    "trials" : [{
        id: "T1"
    }]
};

DISTRACTION_PHASE = {
    "phaseName": "Distraction",
    "templateId": "distractorTrialTemplate",

    // "numBlocks" represents the number of blocks of trials
    // within the current phase. Currently only "1" is supported :)
    "numBlocks": 1,

    distractors: COMMON_LINEUP_DATA.distractors,

    // Trial data will be automatically generated. The following
    // is an example only.
    "trials": [
        {
            id: "D1"
        }
    ]
};

CONFIDENCE_TEMPLATE_DATA = {
    // Fields will be set dynamically in code
    // For use in the html (mustache) template.
}



