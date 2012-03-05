# Vanity.js

Split testing, conversion funnels and feature roll-out.  We got all that.


## Split Tests

The goal of a split test is to find out which one of multiple alternatives performs better.

Say we're selling fluffy animals on the Interwebs.  We're interested in finding out how to get more people to buy our
amazing fluffy creatures.

Our baseline is the current site, with the uninspiring page title "Fluffy animals for sale!".  We thinkg that
highlighting one animal on that page would lead to better sales.  We're going to test this out by changing the title
"Zebras available, get yours now!".

Of course, many other factors can affect sales.  The day of the week, site speed, promotional items, maybe we got a
special mention on the ShitFluffySays blog.  The only way to determine if our new title works better is to run a side by
side comparison.  We're going to split the audience, half will see one title, the other will see the other.  May the
best title win.

We're going to start by defining a very simple split test.  In this case we're testing out two competing alternatives:

```
vanity.split("zerba", 2);
```

Next we'll decide which of these titles to show each of our visitors.

We're essentially conducting an experiment, and our site visitors are participants of that experiment.  We're going to
blindly divide them in two groups.  Each participant will see one of the two alternatives, depending on what group they
belong to.

We also want to be consistent.  Visitors roam around the site before deciding to buy something, we have to make sure
they see the same title on each and every page, otherwise we'll never be able to tell which title influenced them.  So
we need some way to associate visitor with participant.

For this simple test, we'll just go with the session identifier.  We're going to decide that the baseline alternative
(our current title) is number 0, and the new title we're comparing against is number 1.  So our page view would look
like this:

```
if (vanity.show("zebra", req.session.id))
  title = "Zebras available, get yours now!";
else
  title = "Flully animals for sale!";
```

In doing that we captured all our visitors and for each one recorded which alternative they've seen.

Now we want to see how likely they are to buy anything, so let's look at the outcome:

```
post("/checkout", function(req, res, next) {
  vanity.outcome("zebra", req.session.id);
  ...
})
```

We're using the same participant identifier for both: don't mess that up or you'll get results that make no sense.

Now we just sit and wait until we get enough traffic to see a statistically significant difference.


## Getting Fancy

Let's get a bit fancier with split tests.

The simplest split test has two options to choose from, and those are evenly distributed between participants.  If we
don't tell Vanity how many participants are in a test, it will just assume 2.  And if we don't tell Vanity about the
test, it will just create one when we call `show` or `outcome`.

When we do want to call `split` is when we want to tell Vanity more about the split test, or modify an existing test.

Let's start by expanding our test to have 3 different alternatives.  We're going to test out a third title:

```
vanity.split("zebra", 3);
```

We're not sure how well these tests will perform, and we don't want sales to suffer while running our experiment, so
let's limit our experiment to 10% of visitors:

```
vanity.split("zebra", [90, null, null]);
```

The baseline alternative gets 90% of visitors, the other two split what remains.  These are called weights, and we can
always change the weight of a given alternative.  Typically we'll give all alternatives the same weight, or give the
default option significantly more weight.

Say we decided the second alternative is much better, we can "end" the experiment by simply giving that alternative a
weight of 100%.

Let's make it a little bit better and name our three alternatives, so when we look at the results, it's clear what they
refer to:

```
vanity.split("zebra", [["Default title" 90], "Zebras for sale", "Elephant for sale"])
```

Here's how to use the `split` method:
- With one argument, returns an existing split test (doesn't modify it), or creates a new split test with two
  alternatives
- If the second argument is a number, the split test will have at least that many alternatives (you can add, but not
  remove)
- If the second argument is an array, the split test will have at least as many alternatives as listed in the array
- If you want to add more alternatives, add them at the end; never change the order of alternatives, or you'll mess with
  the results
- If you want to disable an alternative, set its weight to zero (not `null`)
- An array item that's a number sets the alternative weigh to that value
- An array item that's `null` sets the alternative weight to equal portion of remaining weights
- An array item that's a string sets the alternative title
- An array item that is itself an array sets the alternative title and weight


## Knowing Your Audience

For split tests to work, the same participant must always belong to the same group.  And participants must be randomly
and evenly distributed between the groups (based on the weight, of course).

The default algorithm works like this:

- Combine the split test name and participant identifier to create a unique string
- Hash it (we use MD5) so the value is evenly and randomly distributed
- Convert the hash into a number, take its modulo of 100
- Each alternative has a range between N and M, where 0 le N le M le 100 and N-M is the assigned weight
- Use the above number to find an alternative based on its N-M range

So the only hard question is, what do we use to identify a participant?  And that, of course, changes from one
application to another.

If you're working with visitors you may want to use session ID or more persistent visitor ID.  If users sign up for the
service, you'll want to use their UID instead.  You may even give them a "vanity ID" that starts in a session and gets
stored in the user account when they sign up.

Some applications have multiple users that are part of the same organization, group or project.  In that case, you may
find it better if all the members of a given group are treated as one participant, using the business identifier to
split test.

Which brings us to the subject of writing your own split-test function.  This allows you to split the audience any way
you see fit.  Business identifier is one option, another is subscription account (free, basic, pro, VC, etc).  For
example:

```
LEVELS = ["Free", "Basic", "Pro", "VC"]
vanity.split("featuris", function(user) {
  return [user.id, LEVELS.indexOf(user.level)];
}, LEVELS)
```

The split function takes one argument, whichever object you pass to `show` or `outcome` and returns an array with two
values.  The first value is the participant identifier, this is used to track individual participants, and the second
value is the alternative number.

This example uses the business identifier to split-test users:

```
vanity.split("featuris", function(user, split) {
  var alt = split.alternativeFor(user.business_id);
  return [user.id, alt];
}, 3)
```

We're using the business identifier to decide which alternative to show, so all users that belong to the same business
see the same UI, but we're using the user identifier to track participation, since it gives us much more granular
results.


## Measuring Outcomes

Simple tests deal with conversion.  We're only interested whether something happened or not.  Did a visitor sign up for
our service?  Did a free user upgrade to paid account?  Did they open up a link in the email?

More complex tests deal with variable outcomes.  Do customers that respond to a coupon spend more on our site?  Does our
new email footer get more people on the "pro" service plan?

To get at that information we record the outcome of each experiment.  For example, let's record the purchase amount:

```
post("/checkout", function(req, res, next) {
  var cart = findCart(req.session.id);
  vanity.outcome(req.session.id, "zebra", cart.total());
  ...
})
```

The third argument can be a number or a string.  If you use a number, Vanity can determine the mean and standard
deviation and compare those across alternatives.  If you use a string, Vanity can determine frequency of occurrences.
This is only useful if you have a small set of known values (e.g. subscription plans).








## Funnels

Funnels take a user through multiple conversion goals.  A funnel can then analyize what percentage completed each goal
before moving to the next one.

To use a funnel you first need to define the steps that make up a funnel:

```
vanity.funnel("shoppe", ["added-to-cart", "checked-out"]);
```

Or add funnel steps to existing experiment:

```
vanity.split("shoppe").funnel(["added-to-cart", "checked-out"]);
```

Then collect the data by calling `outcome` once for each stage, for example:

```
post("/add", function(req, res, next) {
  vanity.outcome(req.session.id, "shoppe", "added-to-cart");
  ...
})

post("/checkout", function(req, res, next) {
  vanity.outcome(req.session.id, "shoppe", "checked-out");
  ...
})
```


## Rolling Out

You can use Vanity.js to roll out features to a subset of users by treating each feature as an experiment and ignoring
the outcome.

Simply define a split for your feature:

```
vanity.rollout("moar_bacon", 10)
```

And write your code so the second alternative is treated as the new feature:

```
if (vanity.show(req.session.id "moar_bacon"))
  req.render "main_with_bacon";
else
  req.render "main";
```


## The Client API

`vanity.split(id)` Returns a split test without modifying it.  If the split-test does't exist, creates and returns a new
one with two alternatives.

`vanity.split(id, number)` Creates and returns a split test with specified number of alternatives (1 or more).  If split
test exists, would add as many alternatives as necessary to read that number.

`vanity.split(id, [alts])` Creates and returns a split test with specified alternatives (1 or more).  Each array item
may be a weight (number), `null` (split remaining weights), alternative title (string) or array with alternative title
and weight.

`vanity.split(id, function, titles)` Creates and returns a split test using the specified function.  The last argument
can be the number of alternatives, or titles for all alternatives.

`vanity.funnel(id)` Returns a funnel without modifying it.  If the funnel doesn't exist, creates and returns a new one.

`vanity.funnel(id, [stages])` Creates and returns a funnel with the specified stages.  If funnel doesn't exist, creates
a new one.

`vanity.rollout(id)` Returns a roll-out without modifying it.  If the roll-out doesn't exist, creates and returns a new
one with 100/0 ratio.

`vanity.rollout(id, ratio)` Creates and returns a feature roll-out.  If roll-out doesn't exist, creates a new one,
otherwise, changes the percentage ratio of the second alternative (value 1) to the specified number.

`vanity.show(participant, experiment)` Returns alternative number to show the specified participant.

`vanity.outcome(participant, experiment, value)` Records that participant has met a particular goal.  Outcome may be a
value (number) or a label (string).  For funnels, outcome must be one of the specified stages.  For roll-out this does
nothing.

The `split`, `funnel` and `rollout` methods all return an object on which you can call `show` and `outcome` with a
single argument.  You can also call `for(participant)`, which returns a object on which you can call `show` and
`outcome` with no arguments (or only the outcome value).

Split tests, funnels and roll-outs all share the same namespace.  Attempting to call `rollout` with identifier already
used for a split test will result in an error.`


## The Web API

### Experiments

Deals with creating, updating, deleting and viewing experiments.

#### List

`GET /v1/experiments`

Returns a JSON document with the property `experiments` listing recent experiments.  The `total` property indicates
total number of experiments.

For example:

```
{ "experiments": [
    { "id": "zerba",
      "type": "experiment",
      "alternatives": [
        { "title": "Default title",
          "ratio": 50,
          "participanting": 250,
          "outcomes": {
            "count": 73,
            "mean": 20,
            "stdev": 8,
            "frequency": {
              10: 35,
              20: 24,
              30: 14
            }
          }
        },
        { "title": "Zebra for sale",
          "ratio": 50,
          "participanting": 12,
          "outcomes": {
            "count": 8,
            "mean": 10,
            "stddev": 3,
            "frequency": {
              10: 5,
              20: 2,
              30: 1
            }
          }
        }
      ],
      "version": 3,
      "modified": "2012-03-01T16:04:21Z",
      "started": "2012-03-01T10:55:23Z"
    }
  ],
  "total": 1
}
```

#### Retrieve

`GET /v1/experiments/:id`

Returns a JSON document with the most recent version of the experiment.

`GET /v1/experiments/:id/:version`

Returns a JSON document with specific version of the experiment.

#### Create/Update

`PUT /v1/experiments/:id`

Creates or updates the experiment from a JSON document.  If the experiment already exists, changes some of its
attributes, otherwise, creates a new experiment.

Properties that are not understood or cannot be changed (e.g.  start time or participating count) are ignored.

You can add new alternatives, change the title and the weight of existing alternatives.  Do not change the order of
alternatives or you will render the results meaningless.  If you want to disable an alternative moving forward, set its
weight to zero.

#### Deleting

`DELETE /v1/experiments/:id`

Deletes the experiment.


### Participants

#### Retrieve Participation

`GET /v1/participant/:experiment/:id`

If the participant participated in this experiment, returns a JSON document describing their participation.  Otherwise,
returns an empty string.

For example:

```
{ "id": "5678",
  "started": "2012-03-01T10:55:23Z",
  "completed": "2012-03-01T10:56:05Z",
  "alternative": 0,
  "outcomes": {
    "gold": "2012-03-01T10:56:05Z"
  }
}
```

#### Mark Participation

`PUT /v1/participant/:experiment/:id`

Used to add participant to this experiment.  Associates the participant with this experiment and returns the alterantive
as a number.  This request is idempotent so can be used multiple times in the same experiment, always returning the same
alternative.

You can also use this to force the participant into a particular alternative.  The alternative can only be set once.

#### Record Outcome

`POST /v1/participant/:experiment/:id`

Used to record the outcome of an experiment.  The document body is a number, string or empty.  The value is used as the
outcome for this particular participant.

This request will create a participant if one doesn't already exist.

Adds to existing list of outcomes for this participant.  Note that duplicate outcomes (same value as previous outcome)
are ignored.

#### Delete Participation

`DELETE /v1/participant/:experiment/:id`

Deletes participant from experiment.


