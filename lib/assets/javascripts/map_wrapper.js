function() {
  var patient = this;
  var effective_date = <%= effective_date %>;

  hqmfjs = {}
  <%= init_js_frameworks %>

  var patient_api = new hQuery.Patient(patient);

  // clear out logger
  if (typeof Logger != 'undefined') Logger.logger = [];
  // turn on logging if it is enabled
  if (Logger.enabled) enableLogging();

  #{measure_js}

  var population = function() {
    return hqmfjs.IPP(patient_api);
  }
  var denominator = function() {
    return hqmfjs.DENOM(patient_api);
  }
  var numerator = function() {
    return hqmfjs.NUMER(patient_api);
  }
  var exclusion = function() {
    return hqmfjs.DENEX(patient_api);
  }
  var exception = function() {
    return hqmfjs.DENEXCEP(patient_api);
  }

  if (Logger.enabled) enableMeasureLogging(hqmfjs);

  map(patient, population, denominator, numerator, exclusion, exception);
};