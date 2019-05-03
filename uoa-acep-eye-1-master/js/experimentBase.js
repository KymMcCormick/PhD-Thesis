// <editor-fold desc="TrialCounter...">

function TrialCounter(nBlocks, nItems)
{
  this.nBlocks = nBlocks;
  this.nItems = nItems;
  this.iTrial = 0;
}

TrialCounter.prototype.getItem = function ()
{
  return this.iTrial % this.nItems;
}

TrialCounter.prototype.isLastItemInBlock = function ()
{
  return this.getItem() == this.nItems - 1;
}

TrialCounter.prototype.getBlock = function ()
{
  return this.iTrial / this.nItems | 0;
}

TrialCounter.prototype.isLastBlock = function ()
{
  return this.getBlock() == this.nBlock - 1;
}

TrialCounter.prototype.getTrial = function ()
{
  return this.iTrial;
}

TrialCounter.prototype.done = function ()
{
  return this.iTrial >= this.nBlocks * this.nItems;
}

TrialCounter.prototype.increment = function ()
{
  ++this.iTrial;
  return this;
}

TrialCounter.prototype.getNumBlocks = function ()
{
  return this.nBlocks;
}

TrialCounter.prototype.getNumItems = function ()
{
  return this.nItems;
}

TrialCounter.prototype.getNumTrials = function ()
{
  return this.nItems * this.nBlocks;
}

// </editor-fold>

// <editor-fold desc="Experiment Class...">

// constructor
function Experiment(name,
                    auth,
                    src,
                    uid,
                    condition,
                    exitCode,
                    savePage)
{
  console.log("Initialising experiment: width=" + $(window).width() + " height=" + $(window).height());
  this.exitCode = exitCode;
  this.savePage = savePage;
  this.condition = condition;

  this.results = new Object();
  this.results["exp"] = name;
  this.results["a"] = auth;
  this.results["src"] = src;
  this.results["uid"] = uid;
  this.results["condition"] = condition;
  
  this.phases = [];
}

Experiment.prototype.addPhase = function (phase)
{
  this.phases.push(phase);
}

Experiment.prototype.start = function ()
{
  console.log("Starting experiment");
  var thisExperiment = this;

  this.startTime = $.now();
  this.results["experimentStartTime"] = this.startTime;
  this.results["windowWidth"] = $(window).width();
  this.results["windowHeight"] = $(window).height();

  if (screen) {
    this.results["screenAvailWidth"] = screen.availWidth;
    this.results["screenAvailHeight"] = screen.availHeight;
  }


  // Save the initial values of interest, so that we can
  // analyse condition specific, or browser specific dropout
  $.post(this.savePage, this.results).always(function () {
    console.log("saved initial data.");
    console.log(thisExperiment.results);
  });

  // If not admin mode then remove any admin controllers
  if (this.results.src !== "admin") {
      $(".adminControl").remove();
  }

  // Start the first phase
  this.currentStage = this.phases.shift();
  this.currentStage.start();
}

Experiment.prototype.next = function ()
{
  if (this.currentStage != null && !this.currentStage.next()) {
    // End the current phase
    this.currentStage.end();
    this.currentStage = this.phases.length == 0 ? null : this.phases.shift();
    
    if (this.currentStage != null) {
      this.currentStage.start();
    }
    else {
      this.end();
    }
  }
}

Experiment.prototype.end = function (msgId)
{
  var exitCode = this.exitCode;
  console.log("Finishing experiment");
  this.results["experimentEndTime"] = this.currentTimeOffset();

  //var nextPage = this.exitPage;
  var results = this.results;

  $.post(this.savePage, results).always(function () {
     console.log("saved results. exit with code: " + exitCode);
     console.log(results);

     if (msgId == null || msgId == "" || msgId == "success") {
       var finishPage = $("#finishPage");
       finishPage.find("#exitCode").html(exitCode);
       finishPage.removeClass("hidden");
     }
     else {
       var errorPage = $("#" + msgId);
       errorPage.removeClass("hidden");
       $("#trialContainerInsertionPoint").addClass("hidden");
     }

     //window.location.href = nextPage;
  });
}

Experiment.prototype.currentTimeOffset = function ()
{
  return $.now() - this.startTime;
}

// </editor-fold>

// <editor-fold desc="FormPhase...">

function FormPhase(experiment, formData)
{
  this.experiment = experiment;
  this.formData = formData;
  this.currentForm = 0;
}

FormPhase.prototype.start = function ()
{
  this.loadForm();
}

FormPhase.prototype.next = function ()
{
  var thisFormPhase = this;

  if (this.currentForm < this.formData.length) {
    var form = this.formData[this.currentForm];
    this.saveResultField(form, "endTime", this.experiment.currentTimeOffset());

    if (form.saveForm == true) {
      var formElement = $('.experimentForm');
      var formFields = formElement.serializeArray();
      var names = {};
      var namesCopy = {};

      for (var iField = 0; iField < formFields.length; ++iField) {
        var name = formFields[iField].name;
        if (names[name] == null) {
          names[name] = 1;
          namesCopy[name] = 1;
        }
        else {
          ++names[name];
          ++namesCopy[name];
        }
      }

      for (iField = 0; iField < formFields.length; ++iField) {
        name = formFields[iField].name;
        var suffix = names[name] == 1 ? "" : "" + (names[name] - (namesCopy[name]--));
        var fieldName = form.name + "_" + name + suffix;
        console.log("saving form " + fieldName + "=" + formFields[iField].value);
        this.experiment.results[fieldName] = formFields[iField].value;
      }
    }

    if (++this.currentForm < this.formData.length) {
      this.loadForm();
      return true;
    }
    else if (this.showing) {
      console.log("hiding form modal");
      $("#formModal").one("hidden.bs.modal", function () {
        thisFormPhase.showing = false;
        thisFormPhase.experiment.next();
      }).modal('hide');

      return true;
    }
  }
  else {
    return false;
  }
}

FormPhase.prototype.handleError = function ()
{
  var form = this.formData[this.currentForm];

  this.saveResultField(form, "endTime", this.experiment.currentTimeOffset());

  if (form.onerror) {
    var formName = form.onerror;

    for (var i=0; i < this.formData.length; ++i) {
      if (formName == this.formData[i].name) {
        this.currentForm = i;
        this.loadForm();
        break;
      }
    }
  }
};

FormPhase.prototype.getTemplateData = function()
{
  return this.formData[this.currentForm].templateData;
};

FormPhase.prototype.postLoadHook = function()
{
};

FormPhase.prototype.loadForm = function()
{
  var thisFormPhase = this;
  var form = this.formData[this.currentForm];
  var modalDialog = $('#modal-dialog');

  modalDialog.removeClass();
  modalDialog.addClass("modal-dialog");

  if (form.className != null) {
      modalDialog.addClass(form.className);
  }

  if (form.template != null) {
    $.get(form.template, function( template ) {
      console.log( "form template loaded: " + form.template);
      var rendered = Mustache.render(template, thisFormPhase.getTemplateData(), form.inclusions);
      $('#formContent').html(rendered);

      thisFormPhase.postLoadHook();
      thisFormPhase.showModal(form);
    });
  }
  else {
    $('#formContent').load(form.url, function() {
      console.log( "form loaded: " + form.url);
      thisFormPhase.postLoadHook();
      thisFormPhase.showModal(form);
    });
  }

  if (form.count == null) {
    form.count = 1;
  }
  else {
    ++form.count;
  }
};

FormPhase.prototype.showModal = function (form)
{
  var thisFormPhase = this;

  if (! this.showing) {
    $("#formModal").one("shown.bs.modal", function () {
      thisFormPhase.showing = true;
      thisFormPhase.saveResultField(form, "startTime", thisFormPhase.experiment.currentTimeOffset());
    }).modal({show: true, keyboard: false, fadeIn: 3000});
  }
  else {
    thisFormPhase.saveResultField(form, "startTime", thisFormPhase.experiment.currentTimeOffset());
  }
}

FormPhase.prototype.end = function ()
{
  console.log("Finished FormPhase");
};

FormPhase.prototype.saveResultField = function(form, name, value)
{
  var param = form.name + "_" + name + "_" + form.count;
  this.experiment.results[param] = value;
  console.log(param + "=" + value);
}

// </editor-fold>

// <editor-fold desc="Interactor Class...">

function Interactor(phase, data)
{
  this.phase = phase;
  this.phaseName = phase.phaseName;

  for (var i in data) {
    this[i] = data[i];
  }
}

Interactor.prototype.translateField = function(name)
{
  // Internationalisation disabled in this experiment.
  return this[name];
};

Interactor.prototype.setContext = function()
{
  var context = this.translateField("context");

  if (context != null) {
    this.phase.trialContainer.find("#stageText").html(context);
  }
};

Interactor.prototype.setReminder = function(explicitValue)
{
  var reminder =  this.translateField("reminder");

  if (explicitValue != null) {
    this.phase.trialContainer.find("#reminderText").html(explicitValue);
  }
  else if (reminder != null) {
    this.phase.trialContainer.find("#reminderText").html(reminder);
  }

};

Interactor.prototype.enable = function(explicitValue) {
    var selector = null;

    if (explicitValue != null && explicitValue != "") {
        selector = explicitValue;
    }
    else if (this.enableSelector != null && this.enableSelector != "") {
        selector = this.enableSelector;
    }

    if (selector != null && selector != "") {
        console.log("enabling: " + selector);
        var enableTarget = this.phase.trialContainer.find(selector);

        if (enableTarget != null) {
            $(enableTarget).addClass("enabled");
            $(enableTarget).removeClass("disabled");
            $(enableTarget).removeAttr("disabled");
        }
        else {
            console.error("invalid enableSelector: " + selector);
        }
    }
}

Interactor.prototype.setQuestion = function()
{
  var question = this.translateField("question");

  if (question != null) {
    this.phase.trialContainer.find("#questionText").html(question);
  }
};

Interactor.prototype.setProgress = function()
{
  var progress = this.progress;

  if (progress !== null) {
    var progressLabel = this.translateField("progressLabel");

    var bar = this.phase.trialContainer.find("#progressBar");
    bar.attr("aria-valuenow", progress);
    bar.attr("style", "width: " + progress + "%");

    if (progressLabel != null) {
      bar.removeClass("sr-only");
      bar.html(progressLabel);
    }
    else {
      console.log("no status text");
      bar.addClass("sr-only");
      bar.html("");
    }
  }
};

Interactor.prototype.getTooltipOptions = function()
{
  return {
    title: this.translateField("tooltip"),
    placement: this.translateField("placement"),
    html: true,
    trigger: "manual",
    container: "body"
  }
};

Interactor.prototype.getAlertOptions = function()
{
  return this.alert;
};

// </editor-fold>

// <editor-fold desc="Experiment Phase Base Class...">

function Phase(experiment, phaseData)
{
  console.log("Initialising Phase: " + phaseData.phaseName + " nTrials: " + phaseData.trials.length + " nBlocks: " + phaseData.numBlocks);
  this.experiment = experiment;
  this.results = experiment.results;
  this.phaseData = phaseData;
  this.phaseName = phaseData.phaseName;
  this.trialTemplateId = phaseData.templateId;
  this.numBlocks = phaseData.numBlocks;

  // Initialise any scripted interaction
  this.previousStep = -1;
  this.currentStep = 0;
  this.nextStep = 1;

  var steps =  INTERACTION_STEPS[this.phaseName];
  this.steps = [];

  for (var s = 0; s < steps.length; ++s) {
    var data = steps[s];

    if (data.conditions === undefined
        || (_.isFunction(data.conditions) && data.conditions(this.experiment.condition))
        || (_.isArray(data.conditions) && data.conditions.indexOf(this.experiment.condition) !== -1)) {

      if (data.if === undefined || data.if === true) {
          var interactor = new Interactor(this, data);
          var count = data.N === undefined ? 1 : data.N;

          for (var i = 0; i < count; ++i) {
              this.steps.push(interactor);
          }
      }
    }
  }
}

Phase.prototype.start = function ()
{
  this.trialCounter = new TrialCounter(this.numBlocks,
                                       this.phaseData.trials.length / this.numBlocks);

  this.startTrial();
}

Phase.prototype.next = function ()
{
  console.log("Phase.next");

  if (! this.trialCounter.done()) {
    if (this.endTrial()) {
      // The conditions for ending a trial have been met
      if (! this.trialCounter.increment().done()) {
        this.startTrial();
      }
    }
  }

  return ! this.trialCounter.done();
}

Phase.prototype.end = function ()
{
  return true;
}

Phase.prototype.setupTrialContainer = function ()
{
  console.log("Phase.setupTrialContainers: this method should be overriden");
}

Phase.prototype.startTrial = function ()
{
  var iTrial = this.trialCounter.getTrial();
  var trialId = this.phaseData.trials[iTrial].id;
  console.log("start " + this.phaseName + " trial: " + iTrial + ", trialType: " + trialId);

  // Record the trial start time
  this.saveResultField("trialStartTime", this.experiment.currentTimeOffset());

  // Record the trial type
  // this.saveResultField("trialType", trialId);

  // Record the trial index
  this.saveResultField("trialIndex", iTrial);

  this.responseCriteria = this.phaseData.trials[iTrial].responseCriteria;
  this.trialContainer = null;
  
  this.setupTrialContainer();

  if (this.steps != null) {
    var thisPhase = this;
    var stepButton = this.trialContainer.find("#stepButton");

    stepButton.bind({
        click: function () {
            thisPhase.step();
        }
    });

    if (iTrial == 0) {
      // only transition to a new state at the start
      // of the first trial.
      this.enterState();
    }
  }
}

Phase.prototype.saveResultField = function(name, value)
{
  var param = this.phaseName + "_" + this.getTrial().id + "_" + name;
  this.results[param] = value;
  console.log("save " + param + " = " + value);
}

Phase.prototype.endTrial = function()
{
  console.log("Phase.endTrial");  
  this.trialContainer.remove();
  
  // Record the trial end time
  this.saveResultField("trialEndTime", this.experiment.currentTimeOffset());
  
  return true;    
}

Phase.prototype.getTrial = function () {
  return this.phaseData.trials[this.trialCounter.getTrial()];
}

Phase.prototype.getCurrentInteractor = function () {
  return this.steps[this.currentStep];
}

Phase.prototype.step = function ()
{
  var interactor = this.steps[this.currentStep];
  this.setNextState(interactor.next);

  if (interactor.advance == null || (interactor.advance(this) == true)) {
      this.previousStep = this.currentStep;
      this.currentStep = this.nextStep;
      this.nextStep = this.currentStep + 1;
  }

  this.enterState();
}

Phase.prototype.setNextState = function (nextState) {
  // if a "next state" is specified and it matches one of the
  // specified states, then the next state will be that state.
  // Otherwise the next state defaults to the next state
  // in sequential order.
  this.nextStep = this.currentStep + 1;
  var nextStateName = null;

  if (nextState != null) {
    if (typeof nextState === "function") {
      nextStateName = nextState(this);
    }
    else {
      nextStateName = "" + nextState;
    }
  }

  if (nextStateName != null && nextStateName != "") {
    for (var i = 0; i < this.steps.length; ++i) {
      if (this.steps[i].id == nextStateName) {
        this.nextStep = i;
        break;
      }
    }
  }
}

Phase.prototype.enterState = function ()
{
  var tooltipTarget;
  var interactor;
  var thisPhase = this;

  if (this.previousStep >= 0) {
    interactor = this.steps[this.previousStep];
    tooltipTarget = this.trialContainer.find(interactor.tipSelector);

    if (interactor.hideTip != null && interactor.hideTip) {
      $(tooltipTarget).tooltip('hide');
    }
    else {
      // Default option is to destroy
      $(tooltipTarget).tooltip('destroy');
    }
  }

  if (this.currentStep < this.steps.length) {
    interactor = this.steps[this.currentStep];

    if (interactor.preProcess != null) {
      interactor.preProcess(this);
    }

    if (interactor.alert != null) {
      this.alert(interactor.getAlertOptions());
    }

    interactor.setReminder();
    interactor.setContext();
    interactor.setQuestion();
    interactor.setProgress();
    interactor.enable();

    if (interactor.enableSelector != null && interactor.enableSelector != "") {
      console.log("enabling: " + interactor.enableSelector);
      var enableTarget = this.trialContainer.find(interactor.enableSelector);

      if (enableTarget != null) {
        $(enableTarget).addClass("enabled");
        $(enableTarget).removeClass("disabled");
        $(enableTarget).removeAttr("disabled");
      }
      else {
        console.error("invalid enableSelector: " + interactor.enableSelector);
      }
    }

    if (interactor.disableSelector != null && interactor.disableSelector != "") {
      console.log("disabling: " + interactor.disableSelector);
      var disableTarget = this.trialContainer.find(interactor.disableSelector);

      if (disableTarget != null) {
        $(disableTarget).addClass("disabled");
        $(disableTarget).attr("disabled","disabled");
        $(disableTarget).removeClass("enabled");
      }
      else {
        console.error("invalid disableSelector: " + interactor.disableSelector);
      }
    }

    if (interactor.coverSelector != null && interactor.coverSelector != "") {
      console.log("hiding: " + interactor.coverSelector);
      var coverTarget = this.trialContainer.find(interactor.coverSelector);

      if (coverTarget != null) {
        $(coverTarget).addClass("invisible");
      }
      else {
        console.error("invalid coverSelector: " + interactor.coverSelector);
      }
    }

    if (interactor.hideSelector != null && interactor.hideSelector != "") {
      console.log("hiding: " + interactor.hideSelector);
      var hideTarget = this.trialContainer.find(interactor.hideSelector);

      if (hideTarget != null) {
        $(hideTarget).addClass("hidden");
      }
      else {
        console.error("invalid hideSelector: " + interactor.hideSelector);
      }
    }

    if (interactor.fadeSelector != null && interactor.fadeSelector != "") {
      console.log("fading: " + interactor.fadeSelector);
      var fadeTarget = this.trialContainer.find(interactor.fadeSelector);

      if (fadeTarget != null) {
        $(fadeTarget).addClass("faded");
      }
      else {
        console.error("invalid fadeSelector: " + interactor.fadeSelector);
      }
    }

    if (interactor.dimSelector != null && interactor.dimSelector != "") {
      console.log("dimming: " + interactor.dimSelector);
      var dimTarget = this.trialContainer.find(interactor.dimSelector);

      if (dimTarget != null) {
        $(dimTarget).addClass("dim");
      }
      else {
        console.error("invalid dimSelector: " + interactor.fadeSelector);
      }
    }

    if (interactor.revealSelector != null && interactor.revealSelector != "") {
      console.log("revealing: " + interactor.revealSelector);
      var revealTarget = this.trialContainer.find(interactor.revealSelector);

      if (revealTarget != null) {
        $(revealTarget).removeClass("invisible");
        $(revealTarget).removeClass("hidden");
        $(revealTarget).removeClass("faded");
        $(revealTarget).removeClass("dim");
      }
      else {
        console.error("invalid revealSelector: " + interactor.revealSelector);
      }
    }

    if (interactor.focusSelector != null && interactor.focusSelector != "") {
      console.log("focusing: " + interactor.focusSelector);
      var focusTarget = this.trialContainer.find(interactor.focusSelector);

      if (focusTarget != null) {
        $(focusTarget).addClass("focused");
      }
      else {
        console.error("invalid focusSelector: " + interactor.focusSelector);
      }
    }

    if (interactor.unfocusSelector != null && interactor.unfocusSelector != "") {
      console.log("unfocusing: " + interactor.unfocusSelector);
      var unfocusTarget = this.trialContainer.find(interactor.unfocusSelector);

      if (unfocusTarget != null) {
        $(unfocusTarget).removeClass("focused");
      }
      else {
        console.error("invalid unfocusSelector: " + interactor.unfocusSelector);
      }
    }

    console.log("tipping: " + interactor.tipSelector);
    tooltipTarget = this.trialContainer.find(interactor.tipSelector);
    $(tooltipTarget).tooltip(interactor.getTooltipOptions());

    if (interactor.showTip == null || interactor.showTip) {
      $(tooltipTarget).tooltip('show');
    }

    this.trialContainer.find("#stepButton").focus();

    if (interactor.id != null && interactor.timestamp) {
      this.saveResultField("enterState_" + interactor.id, this.experiment.currentTimeOffset());
    }

    if (interactor.postProcess != null) {
      interactor.postProcess(this);
    }

    if (interactor.autoTransition != null) {
      setTimeout(function () { thisPhase.step() }, interactor.autoTransition);
    }
  }
}

Phase.prototype.alert = function (options)
{
  var thisPhase = this;
  var dialog = $("#promptDialog");

  dialog.unbind();

  dialog.on("hidden.bs.modal", function (event) {
    thisPhase.step();
  })

  dialog.on("shown.bs.modal", function (event) {
    dialog.find("#continueButton").focus();
  })

  dialog.modal({ keyboard : false });

  dialog.find("#alertTitle").html(options.title || "");
  dialog.find("#alertBody").html(options.body || "");
  // i18n issue
  dialog.find("#alertPrompt").html(options.prompt || "Click here to continue");

  dialog.find("#continueButton").unbind();
  dialog.find("#continueButton").bind("click", function () {
    dialog.modal('hide');
  });

  dialog.modal("show");
}

Phase.prototype.checkAnswer = function ()
{
  console.log("check answer");

  var response = this.answerSelector.getAnswer();

  console.log(" answer: " + response);

  if (response != null) {
    var correct = this.responseCriteria.preferredResponse;

    if (correct == "" || correct == null || correct == response) {
      this.saveResultField("trialResponse", response);
      this.answerSelector.end();
      this.answerSelector = null;
      return 1;
    }
    else {
      this.saveResultField("trialIncorrectResponse", response);
      //var dialog = $("#incorrectResponseDialog");
      //dialog.modal("show");
      return -1;
    }
  }
  else {
    //var dialog = $("#pleaseRespondDialog");
    //dialog.modal("show");
    return 0;
  }
}

// </editor-fold>

// The following is necessary for form validation

// i18n issue

$.validator.addMethod("equals", function (value, element, param) {
    return this.optional(element) || param == value;
}, "Incorrect value");

$.validator.addMethod("isIn", function (value, element, param) {
    return this.optional(element) || param.indexOf(value) != -1;
}, "Invalid value");

// Miscellaneous

/**
 * Randomize array element order in-place.
 * Only shuffle elements in the given range
 * startIndex defaults to 0, endIndex defaults to length - 1
 * Using Fisher-Yates shuffle algorithm.
 */
Array.prototype.shuffle = function (startIndex,endIndex)
{
    var s = startIndex == undefined ? 0 : startIndex;
    var e = endIndex == undefined ? (this.length - 1) : endIndex;

    for (var i = e; i > s; i--) {
        var j = s + Math.floor(Math.random() * (i - s + 1));
        var temp = this[i];
        this[i] = this[j];
        this[j] = temp;
    }
    return this;
}

function getParameterByName(name, url) {
    if (!url) url = window.location.href;
    name = name.replace(/[\[\]]/g, "\\$&");
    var regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)");
    var results = regex.exec(url);

    if (!results) return null;

    if (!results[2]) return '';

    return decodeURIComponent(results[2].replace(/\+/g, " "));
}
