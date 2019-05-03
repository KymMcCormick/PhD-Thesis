

PAUSE = {
  autoTransition: 2000
};

INTRO_STEP_1 =
{
    hideSelector: "#contentPanel",
    coverSelector: "#stageText, #questionText",
    tipSelector: "#reminderText",
    question: "Are you ready to watch a video?",
    tooltip: 'The button will advance you through the experiment. \
                      Look here if you are unsure of what to do at any stage.',
    placement: "top",
    context: "Introduction",
    reminder: "Click here to start the experiment..."
};

INTRO_STEP_2 =
{
    revealSelector: "#stageText",
    tipSelector: "#stageText",
    tooltip: 'This area of the screen will tell you what stage \
                of the experiment you are in.',
    placement: "left",
    reminder: "Click here to read more..."
};


INTERACTION_STEPS = {

    Study: [
        INTRO_STEP_1,
        INTRO_STEP_2,

        {
            context: "Study Phase",
            revealSelector: "#questionText, #p1",
            reminder: "Click here play the video..."
        },

        {
            id: "startVideo",
            timestamp: true,
            hideSelector: "#studyTrialPanel",
            revealSelector: "#contentPanel",

            postProcess: function (phase) {
                phase.initializeVideoPlayer();
            }
        },

        {
            id: "readyVideo",
            timestamp: true,

            postProcess: function (phase) {
                phase.playVideo();
            },

            next: function(phase) {
                return phase.hasFinished() ? "videoSuccess" : "videoFailed"
            }
        },

        {
            id: "videoSuccess",
            timestamp: true,
            revealSelector: "#trialPanel",

            postProcess: function (phase) {
                phase.experiment.next();
            }
        },

        {
            id: "videoFailed",
            timestamp: true,
            revealSelector: "#trialPanel, #videoFail"
        }
    ],

    Distraction: [
        {
            context: "Attention Task",
            revealSelector: "#p1",
            reminder: "Click here to continue..."
        },

        {
            id: "startVideo0",
            timestamp: true,
            hideSelector: "#distractorTrialPanel, #p1, #moreVideos",
            revealSelector: "#contentPanel-0",

            postProcess: function (phase) {
                phase.initializeVideoPlayer(0);
            }
        },

        {
            timestamp: true,

            postProcess: function (phase) {
                phase.playVideo();
            },

            next: function(phase) {
                return phase.hasFinished() ? "videoSuccess0" : "videoFailed"
            }
        },

        {
            id: "videoSuccess0",
            timestamp: true,
            hideSelector: "#contentPanel-0",
            revealSelector: "#contentPanel-1",

            postProcess: function (phase) {
                phase.initializeVideoPlayer(1);
            }
        },

        {
            timestamp: true,

            postProcess: function (phase) {
                phase.playVideo();
            },

            next: function(phase) {
                return phase.hasFinished() ? "videoSuccess1" : "videoFailed"
            }
        },

        {
            id: "videoSuccess1",
            timestamp: true,
            hideSelector: "#p1, #contentPanel-1",
            coverSelector: "#instructionStepper",
            revealSelector: "#distractorTrialPanel, #p2"
        },

        {
            reminder: "Click here to confirm your answer",
            revealSelector: "#instructionStepper"
        },

        {
            preProcess: function (phase) {
                phase.experiment.next();
            },

            context: "Attention Task",
            hideSelector: "#p1, #p2",
            revealSelector: "#moreVideos",
            reminder: "Click here to continue",
            next: "startVideo0"
        },

        {
            id: "videoFailed",
            timestamp: true,
            revealSelector: "#trialPanel, #videoFail"
        }
    ],

    Test: [
        {
            context: "Identification Phase",
            revealSelector: "#p1",
            question: "Identification from a lineup",
            reminder: "Click here to continue..."
        },

        {
            id: "startLineup",
            timestamp: true,
            hideSelector: "#p1",
            revealSelector: "#lineupPanel",
            enableSelector: "#lineupPanel",
            disableSelector: "#stepButton",
            question: "Do you see the person from the <b>ORIGINAL</b> video?",
            reminder: "Click on the image of the person from the <b>ORIGINAL</b> video...",

            postProcess: function (phase) {
                phase.suspectSelector.activate();
            },

            next: function (phase) {
                let more = phase.processSelection();
                return "lastSuspect";
            }
        },

        {
            id: "lastSuspect",

            postProcess: function (phase) {
                phase.experiment.next();
            }
        }
    ],

    Rank: [
        {
            context: "Ranking Phase",
            revealSelector: "#p1",
            question: "Ranking the lineup",
            reminder: "Click here to continue..."
        },

        {
            id: "startLineup",
            timestamp: true,
            hideSelector: "#p1",
            revealSelector: "#lineupPanel",
            enableSelector: "#lineupPanel",
            disableSelector: "#stepButton",
            question: "Who most resembles the person from the <b>ORIGINAL</b> video?",
            reminder: "Click on the photo that most resembles the person from the <b>ORIGINAL</b> video...",

            postProcess: function (phase) {
                phase.suspectSelector.activate();
            },

            next: function (phase) {
                var more = phase.processSelection();
                return more ? "selectNextBest" : "lastSuspect";
            }
        },

        {
            id: "selectNextBest",
            timestamp: true,
            hideSelector: "#p2-1, #p2-2",
            revealSelector: "#p2-1b, #p2-2b",
            enableSelector: "#lineupPanel",
            disableSelector: "#stepButton",
            reminder: "Click on the photo that most resembles the person from the <b>ORIGINAL</b> video...",

            postProcess: function (phase) {
                phase.suspectSelector.activate();
            },

            next: function (phase) {
                var more = phase.processSelection();
                return more ? "selectNextBest" : "lastSuspect";
            }
        },

        {
            id: "lastSuspect",

            postProcess: function (phase) {
                phase.experiment.next();
            }
        }
    ]
}
