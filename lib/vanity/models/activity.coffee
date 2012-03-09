{ Model } = require("poutine")


class Activity extends Model
  @collection "activities"

  @field "actor"
  @field "verb", String
  @field "object"
  @field "target"
  @field "labels", Array


module.exports = Activity
