{ Model } = require("poutine")


class Activity extends Model
  @collection "activities"

  @field "actor"
  @field "verb", String
  @field "object"
  @field "target"
  @field "labels", Array

  @create = (params, callback)->
    doc =
      _id: params.id
      actor:
        displayName:  params.actor?.displayName || "John Smith"
        url:          params.actor?.url
        image:        params.actor?.image

    Activity.insert doc, callback



module.exports = Activity
