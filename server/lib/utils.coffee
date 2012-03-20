Util =
  # Returns 32-bit has code from a string (based on Java's hashCode)
  hashCode: (string)->
    if string.length == 0
      return 0
    hash = 0
    for i in [0...string.length]
      char = string.charCodeAt(i)
      hash = ((hash << 5) - hash) + char
      hash = hash & hash # Convert to 32bit integer
    return Math.abs(hash)


module.exports = Util
