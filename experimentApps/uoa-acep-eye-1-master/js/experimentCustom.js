/**
 * Created by kransom on 28/07/2018.
 */

// <editor-fold desc="StudyPhase Class...">

function BasicPhase(experiment, phaseData) {
    this.preProcessData(experiment, phaseData);
    Phase.call(this, experiment, phaseData);
}

BasicPhase.prototype = Object.create(Phase.prototype);

BasicPhase.prototype.preProcessData = function(experiment, phaseData)  {}

BasicPhase.prototype.setupTrialContainer = function ()
{
    var thisPhase = this;
    var iTrial = this.trialCounter.getTrial();
    var trial = this.getTrial();

    trial.numTrials = this.trialCounter.getNumTrials();
    trial.trialNum = 1 + iTrial;
    trial[this.experiment.condition] = true;
    trial.condition = this.experiment.condition;

    // var templates = this.getTemplates();
    var trialTemplate = $("#" + this.trialTemplateId).html();
    var rendered = Mustache.render(trialTemplate, trial /* templates */);

    var insertionPoint = $("#trialContainerInsertionPoint");
    insertionPoint.html(rendered);

    this.trialContainer = insertionPoint.find("#" + trial.id);
    this.trialContainer.find("#trialNum").text("" + (trial.trialNum));
    this.trialContainer.removeClass("hidden");
}

BasicPhase.prototype.wasPaused = function () {
    return this.paused;
}

BasicPhase.prototype.hasFinished = function () {
    return this.finished;
}

BasicPhase.prototype.initializeVideoPlayer = function (
    videoId,
    targetId,
    htmlElementId,
    prefix)
{
    let phase = this;
    this.paused = false;
    this.finished = false;
    let numPause = 0;
    let numPlay = 0;

    let player = new YT.Player(htmlElementId, {
        //width: 600,
        //height: 400,
        videoId: videoId,
        playerVars: {
            autoplay: 0,
            color: 'red',
            controls: 0,
            disablekb: 1,
            enablejsapi: 1,
            fs: 0, // disable fullscreen
            iv_load_policy: 3,
            modestbranding: 1,
            rel : 0,
            showinfo : 0
        },
        events: {
            onReady: function () {
                console.log("video onReady fired");
                player.setPlaybackQuality("hd720");
                phase.step();
            },

            onStateChange: function (event) {
                var state = event.data;

                if (state == YT.PlayerState.ENDED) {
                    console.log("video finished");
                    phase.finished = true;
                    phase.saveResultField(prefix + "_" + "ended", phase.experiment.currentTimeOffset());
                    phase.saveResultField(prefix + "_" + "videoId", videoId)
                    phase.saveResultField(prefix + "_" + "targetId", targetId)
                    phase.step();
                }
                else if (state == YT.PlayerState.PAUSED) {
                    console.log("video player paused");
                    phase.paused = true;
                    ++numPause;
                    phase.saveResultField(prefix + "_" + "paused_" + numPause, phase.experiment.currentTimeOffset());
                    phase.experiment.end("videoPaused");
                }
                else if (state == YT.PlayerState.PLAYING) {
                    console.log("video player playing");
                    ++numPlay;
                    phase.saveResultField(prefix + "_" + "play_" + numPlay, phase.experiment.currentTimeOffset());
                    phase.saveResultField(prefix + "_" + "quality_" + numPlay, player.getPlaybackQuality());
                }
            }
        }
    });

    return player;
}

// </editor-fold>

// <editor-fold desc="StudyPhase Class...">

function StudyPhase(experiment, phaseData) {
    BasicPhase.call(this, experiment, phaseData);
}

StudyPhase.prototype = Object.create(BasicPhase.prototype);

StudyPhase.prototype.preProcessData = function(experiment, phaseData)
{
    let lineupData = phaseData.lineupData;
    let trials = phaseData.trials;
    let presence = targetPresence(experiment.condition);

    lineupData.suspects.shuffle();

    // In this experiment, the target is not always present
    if (presence === "P") {
        lineupData.suspects.unshift(lineupData.target)
    }

    lineupData.suspects = lineupData.suspects.slice(0,lineupData.lineupSize);

    lineupData.suspects.shuffle();
}

StudyPhase.prototype.initializeVideoPlayer = function () {
    let videoId = this.phaseData.lineupData.target.video;
    let targetId = this.phaseData.lineupData.target.id;
    let htmlElementId = 'video-placeholder';

    this.player = BasicPhase.prototype.initializeVideoPlayer.call(
        this,
        videoId,
        targetId,
        htmlElementId,
        "V" + 1);
}

StudyPhase.prototype.playVideo = function () {
    this.player.playVideo();
}

// </editor-fold>

// <editor-fold desc="TestPhase Class...">

function TestPhase(experiment, phaseData) {
    BasicPhase.call(this, experiment, phaseData);
}

TestPhase.prototype = Object.create(BasicPhase.prototype);

TestPhase.prototype.preProcessData = function(experiment, phaseData)
{
    let trials = phaseData.trials;
    let s = experiment.condition.split("_");

    CHOICE_TEMPLATE_DATA[s[0]] = true; // "S" (Strong memory), or "W" (Weak)
    CHOICE_TEMPLATE_DATA[s[1]] = true; // "H" (High Expectation), or "L" (Low)
    CHOICE_TEMPLATE_DATA[s[2]] = true; // "P" (Target Present), or "A" (Absent)

    // Iterate over all trials
    for (let i = 0; i < trials.length; ++i) {
        let trialData = trials[i];

        trialData[s[0]] = true; // "S" (Strong memory), or "W" (Weak)
        trialData[s[1]] = true; // "H" (High Expectation), or "L" (Low)
        trialData[s[2]] = true; // "P" (Target Present), or "A" (Absent)

        trialData.target = phaseData.lineupData.target;
        trialData.lineupSize = phaseData.lineupData.lineupSize;
        trialData.suspects = phaseData.lineupData.suspects;
        trialData.silhouette = phaseData.lineupData.silhouette;
        trialData.currentSuspect  = 0;

        for (let j = 0; j < trialData.suspects.length; ++j) {
            trialData.suspects[j].suspectIndex = j
        }
    }
}

TestPhase.prototype.setupTrialContainer = function (templateId)
{
    BasicPhase.prototype.setupTrialContainer.call(this, templateId);

    let iTrial = this.trialCounter.getTrial();
    let trial = this.getTrial();

    this.suspectSelector = new SuspectSelector(
        this,
        this.trialContainer.find("#lineupPanel"),
        trial.lineupSize);

    this.saveLineupOrder(trial);
    this.saveResultField("target", trial.target.id);
    this.saveResultField("lineupSize", trial.lineupSize);

    trial.selectionOrder = [];
    trial.selectionTime = [];
}

TestPhase.prototype.saveLineupOrder = function(trial)
{
    trial.lineupOrder = _.map(trial.suspects, function (suspect) {
        return suspect.id;
    })

    let order = trial.lineupOrder.join(":");
    this.saveResultField("lineupOrder", order);
}

TestPhase.prototype.processSelection = function() {
    let trial = this.getTrial();
    let suspectId = this.suspectSelector.getSuspect();
    trial.selectedSuspect = suspectId;
    trial.identificationTime = this.experiment.currentTimeOffset();

    if (suspectId === "Silhouette") {
        CHOICE_TEMPLATE_DATA.reject = true;
    }
}

TestPhase.prototype.endTrial = function() {
    let trial = this.getTrial();

    this.saveResultField("suspectIdentified", trial.selectedSuspect);
    this.saveResultField("identificationTime", trial.identificationTime);

    return BasicPhase.prototype.endTrial.call(this);
}

// </editor-fold>

// <editor-fold desc="RankPhase Class...">

function RankPhase(experiment, phaseData) {
    BasicPhase.call(this, experiment, phaseData);
}

RankPhase.prototype = Object.create(BasicPhase.prototype);

RankPhase.prototype.preProcessData = function(experiment, phaseData)
{
    let trials = phaseData.trials;
    let s = experiment.condition.split("_");
    // Iterate over all trials

    for (let i = 0; i < trials.length; ++i) {
        let trialData = trials[i];

        trialData[s[0]] = true; // SEQ (Sequential), SIM (Simultaneous) Lineup

        trialData.target = phaseData.lineupData.target;
        trialData.lineupSize = phaseData.lineupData.lineupSize;
        trialData.suspects = phaseData.lineupData.suspects;
        trialData.currentSuspect  = 0;

        for (let j = 0; j < trialData.suspects.length; ++j) {
            trialData.suspects[j].suspectIndex = j
        }
    }
}

RankPhase.prototype.setupTrialContainer = function (templateId)
{
    BasicPhase.prototype.setupTrialContainer.call(this, templateId);

    let iTrial = this.trialCounter.getTrial();
    let trial = this.getTrial();

    this.suspectSelector = new SuspectSelector(
        this,
        this.trialContainer.find("#lineupPanel"),
        trial.lineupSize);

    this.saveLineupOrder(trial);
    this.saveResultField("target", trial.target.id);
    this.saveResultField("lineupSize", trial.lineupSize);

    trial.selectionOrder = [];
    trial.selectionTime = [];
}

RankPhase.prototype.saveLineupOrder = function(trial)
{
    trial.lineupOrder = _.map(trial.suspects, function (suspect) {
        return suspect.id;
    })

    let order = trial.lineupOrder.join(":");
    this.saveResultField("lineupOrder", order);
}

RankPhase.prototype.processSelection = function() {
    let trial = this.getTrial();
    let suspect = this.suspectSelector.getSuspect();
    trial.selectionTime.push(this.experiment.currentTimeOffset());
    trial.selectionOrder.push(suspect);

    return this.suspectSelector.moreToSelect();
}

RankPhase.prototype.endTrial = function() {
    let trial = this.getTrial();

    let remainingSuspect = _.difference(trial.lineupOrder, trial.selectionOrder)
    trial.selectionOrder.push(remainingSuspect[0]);

    this.saveResultField("originalIdentification", trial.selectionOrder[0]);
    this.saveResultField("selectionOrder", trial.selectionOrder.join(":"));
    this.saveResultField("selectionTime", trial.selectionTime.join(":"));

    return BasicPhase.prototype.endTrial.call(this);
}

// </editor-fold>

// <editor-fold desc="DistractionPhase...">

function DistractionPhase(experiment, phaseData) {
    BasicPhase.call(this, experiment, phaseData);
}

DistractionPhase.prototype = Object.create(BasicPhase.prototype);

DistractionPhase.prototype.preProcessData = function(experiment, phaseData)
{
    // Trials will be automatically generated
    phaseData.trials = [];
    let ms = memoryStrength(experiment.condition);
    let numTrials = phaseData.numTrials[ms];

    phaseData.distractors.shuffle();

    for (let i = 0; i < numTrials; ++i) {
        let trialData = { id: "D" + (i+1) };
        trialData.distractors = phaseData.distractors.slice(i * 2, (i + 1) * 2);

        for (let j = 0; j < trialData.distractors.length; ++j) {
            trialData.distractors[j].distractorIndex = j
        }

        if (numTrials > 1) {
            let t = numTrials - i;
            let suffix = (t > 1 ? "s" : "");
            trialData.morePairs = "" + t + " more time" + suffix;
        }

        phaseData.trials[i] = trialData;
    }
}

DistractionPhase.prototype.setupTrialContainer = function (templateId)
{
    BasicPhase.prototype.setupTrialContainer.call(this, templateId);

    let thisPhase = this;
    let iTrial = this.trialCounter.getTrial();
    let trial = this.phaseData.trials[iTrial];
    let questionElement = this.trialContainer.find(".questionForm");

    // Reset the question radio buttons
    let radioButtons = questionElement.find("input");
    radioButtons.prop('checked', false);

    this.answerChanged = false;

    $("body").bind("keypress", function (e) {
        let code = (e.keyCode ? e.keyCode : e.which);
        console.log("key up: " + code);

        if (code >= 49 && code <= 58) {
            // code 49 => 1, 50 => 2, ..., 58 => 9
            let option = code - 48;
            questionElement.find('#option' + option).prop('checked', true);
            radioButtons.change();
            thisPhase.trialContainer.find("#stepButton").focus();
        }
    });

    radioButtons.bind("change", function () {
        if (! thisPhase.answerChanged) {
            thisPhase.answerChanged = true;
            thisPhase.step();
        }

        thisPhase.trialContainer.find("#stepButton").focus();
    });

    //this.saveResultField("face1", trial.faces[0]);
    //this.saveResultField("face2", trial.faces[1]);

    //if (this.experiment.results.src === "admin") {
    //    $("#adminPanel #face1").html(trial.faces[0]);
    //    $("#adminPanel #face2").html(trial.faces[1]);
    //}

}

DistractionPhase.prototype.initializeVideoPlayer = function (distractorIndex) {
    let trialData = this.getTrial();
    let target = trialData.distractors[distractorIndex];

    let videoId = target.video;
    let targetId = target.id;
    let htmlElementId = 'video-placeholder-' + distractorIndex;

    this.player = BasicPhase.prototype.initializeVideoPlayer.call(
        this,
        videoId,
        targetId,
        htmlElementId,
        "V" + (distractorIndex + 1));
}

DistractionPhase.prototype.playVideo = function () {
    this.player.playVideo();
}

DistractionPhase.prototype.endTrial = function() {
    //$("body").unbind("keypress");
    let thisPhase = this;
    let selected = this.trialContainer.find(".questionForm input:radio:checked");

    selected.each(function (index) {
        let value = $(this).val();
        thisPhase.saveResultField("response", value);
    });

    return BasicPhase.prototype.endTrial.call(this);
}


// </editor-fold desc="DistractionPhase...">

// <editor-fold desc="SuspectSelector Class...">

function SuspectSelector(phase, container, lineupSize)
{
  this.phase = phase;
  this.lineupSize = lineupSize;
  console.log("Constructing SuspectSelector: ");
  this.container = container;
  this.selectionCount = 0;
}

SuspectSelector.prototype.activate = function()
{
    // de-select any previous suspect
    let suspect = this.container.find(".suspectContainer.selected");
    suspect.addClass("hidden");
    suspect.removeClass("selected");

    this.selectedSuspect = "noSelection";

    this.bind();

    --this.lineupSize;
}

SuspectSelector.prototype.moreToSelect = function()
{
    return this.lineupSize >= 2;
}

SuspectSelector.prototype.bind = function()
{
  var thisInteraction = this;
  this.container.find('.suspectImage').unbind();

  this.container.find('.suspectImage').bind(
    "click",
    function(event) {
      thisInteraction.selectSuspect(this);
    }
  );
}

SuspectSelector.prototype.select = function(suspectSelector)
{
  return this.selectSuspect(this.container.find(suspectSelector)[0]);
}

SuspectSelector.prototype.getSuspect = function() {
    return this.selectedSuspect;
}

SuspectSelector.prototype.selectSuspect = function(selectedImage)
{
    console.log("Suspect clicked: " + selectedImage.id);

    if (this.container.hasClass("enabled")) {
        ++this.selectionCount;

        if (this.selectedSuspect == "noSelection") {
            this.phase.getCurrentInteractor().enable("#stepButton");
            this.phase.trialContainer.find("#stepButton").focus();
            this.phase.getCurrentInteractor().setReminder("Click here to confirm your choice...");
        }

        // de-select previous suspect
        let suspect = this.container.find(".suspectContainer#" + this.selectedSuspect);
        suspect.removeClass("selected");

        // select current suspect
        this.selectedSuspect = selectedImage.id;
        suspect = this.container.find(".suspectContainer#" + this.selectedSuspect);
        suspect.addClass("selected");

    }
}

// </editor-fold>