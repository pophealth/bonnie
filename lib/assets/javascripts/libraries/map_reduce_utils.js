// Adds common utility functions to the root JS object. These are then
// available for use by the map-reduce functions for each measure.
// lib/qme/mongo_helpers.rb executes this function on a database
// connection.

var root = this;

root.map = function(record, population, denominator, numerator, exclusion, denexcep, occurrenceId) {
  var value = {population: 0, denominator: 0, numerator: 0, denexcep: 0,
               exclusions: 0, antinumerator: 0, patient_id: record._id,
               medical_record_id: record.medical_record_number,
               first: record.first, last: record.last, gender: record.gender,
               birthdate: record.birthdate, test_id: record.test_id,
               provider_performances: record.provider_performances,
               race: record.race, ethnicity: record.ethnicity, languages: record.languages};
  var ipp = population()
  if (hqmf.SpecificsManager.validate(ipp)) {
    value.population = hqmf.SpecificsManager.countUnique(occurrenceId, ipp);
    var exclusions = hqmf.SpecificsManager.intersectSpecifics(exclusion(), ipp);
    var denom = hqmf.SpecificsManager.intersectSpecifics(denominator(), ipp);
    if (hqmf.SpecificsManager.validate(exclusions)) {
      value.exclusions = hqmf.SpecificsManager.countUnique(occurrenceId, exclusions);
      denom = hqmf.SpecificsManager.exclude(occurrenceId, denom, exclusions);
    }
    if (hqmf.SpecificsManager.validate(denom)) {
      var numer = hqmf.SpecificsManager.intersectSpecifics(numerator(), denom);
      if (hqmf.SpecificsManager.validate(numer)) {
        value.numerator = hqmf.SpecificsManager.countUnique(occurrenceId, numer);
      }
      var excep = hqmf.SpecificsManager.intersectSpecifics(denexcep(), denom);
      if (hqmf.SpecificsManager.validate(excep)) {
        excep = hqmf.SpecificsManager.exclude(occurrenceId, excep, numer);
        value.denexcep = hqmf.SpecificsManager.countUnique(occurrenceId, excep);
        denom = hqmf.SpecificsManager.exclude(occurrenceId, denom, excep);
      }
      value.denominator = hqmf.SpecificsManager.countUnique(occurrenceId, denom);
      value.antinumerator = value.denominator-value.numerator;
    }
  }


  if (typeof Logger != 'undefined') value['logger'] = Logger.logger
  
  emit(ObjectId(), value);
};
