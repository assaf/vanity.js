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
if (vanity.show("zebra", req.session.id)) {
  title = "Zebras available, get yours now!";
} else {
  title = "Flully animals for sale!";
}
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
  vanity.outcome("zebra", req.session.id, cart.total());
  ...
})
```

The third argument can be a number or a string.  If you use a number, Vanity can determine the mean and standard
deviation and compare those across alternatives.  If you use a string, Vanity can determine frequency of occurrences.
This is only useful if you have a small set of known values (e.g. subscription plans).


## Funnels

Funnels take a user through multiple conversion goals, analyzing what percentage completed each goal before moving on to
the next one.  Or, if you like, what percentage dropped off at each step of the way.

Defining a funnel is as easy as naming it and listing the steps:

```
vanity.funnel("laundry", ["washed", "dried", "folded"]);
```

Once again we collect data by calling `outcome`, and specify the step just completed.  For example:

```
post("/wash", function(req, res, next) {
  ...
  vanity.outcome("laundry", req.session.id, "washed");
})

post("/dry", function(req, res, next) {
  ...
  vanity.outcome("laundry", req.session.id, "dried");
})
```

There is no point in calling `show` on a funnel.


## Rolling Out

You can also use Vanity.js to roll out a feature to a subset of users.  It works much like a split test with a default
option and second option that is progressively exposed to more and more users.

To roll out a feature to 10% of users:

```
vanity.rollout("moar_bacon", 10);
```

Essentially there are two alternatives, the default (number 0) and the feature we're rolling out (number 1).  Because 0
evaluates to `false` and one to `true` we can write our code like this:

```
if (vanity.show("moar_bacon", req.session.id)) {
  req.render "main_with_bacon";
} else {
  req.render "main_original";
}
```
There is no point in calling `outcome` on a roll-out.


## Activity Stream

Vanity includes an activity stream you can use to visualize usage of your application.

Each activity consists of an actor and a verb: the person performing an action, and the action being performed.  An
activity may also include an object, a target and any number of labels.

Most actions are performed on an object, e.g.  posting a comment or uploading a video.  Some actions have an object and
a target, e.g. the object of the post would be the comment, and the target of the post would be the comment thread.

Labels are used to classify and filter activities.

This examples records that I upvoted a post on the HackerNews site:

```
var actor = {
  id: "aarkin",
  displayName: "Assaf Arkin",
  image: {
    url: "http://content.labnotes.org/profile-photo.jpg",
    width: 304,
    height: 398
  },
  url: "http://arkin.me",
  objectType: "person"
}
var object = {
  id: "3667450",
  displayName: "Induction: A Polyglot Database Client For Mac OS X",
  url: "http://news.ycombinator.com/item?id=3667450",
  objectType: "post"
}
var target = {
  id: "hackernews",
  displayName: "Hacker News",
  url: "http://news.ycombinator.com",
  objectType: "site"
}
var labels = [
  "vote:up"
]
vanity.activity(actor, "upvoted", { object: object, target: target, labels: labels })
```

For more information, see the [JSON Activity Streams 1.0](http://activitystrea.ms/specs/json/1.0/)


## Using Vanity On The Server

There are two parts to this.  The first part deals with configuring Vanity and connecting it to a back-end.  Whether you
intend to use Vanity on the server, only in the browser, or in both, you need to follow this step.

The second part deals with using split tests, roll-outs, activity stream, etc.  For these you just need to require the
`vanity` module and use it per the examples above.

So let's show you how to configure Vanity.

**TBD**


## Using Vanity In The Browser

The basic requirement for using Vanity in the browser is including the JavaScript library.  For example:

```
<script src="/scripts/vanity.js"></script>
```

Vanity supports the CommonJS module system, so you can require it as part of a module definition.

Of course, nothing much will happen if Vanity is disconnected from the server, so you need to configure it on the server
(see above) and attach the handler to an endpoint of your choice.  For example, with Express you could do this:

```
server.post("/vanity", Vanity.handler());
```

In the browser, point Vanity at the same endpoint:

```
vanity.connect("/vanity");
```

Voila.  You may also want to specify a refresh interval, the default is 5 seconds.



## The Client API

### Vanity module

#### split(id)

Returns a `SplitTest` without modifying it.  If there is no such split test, creates a new one with two alternatives.

#### split(id, number)

Returns a `SplitTest` with the specified number of alternatives.  If the split test already exists, modifies it to have
at least as many alternatives as specified by the second argument.

#### split(id, [alt ...])

Returns a `SplitTest` with the specified number of alternatives.  If the split test already exists, modifies is to have
at least as many alternatives as specified, and changes alternative weights and titles as specified by the array.

Each array element can be one of:
- Weight to assign that alternative (number betwee 0 and 100)
- `null` to assign that alternative an equal split of the remaining weight
- A title for that alternative
- An array with title and weight

#### split(id, function, number)

Returns a `SplitTest` using the specified split function and number of alternatives.  If the split test already exists,
modifies it to have at least as many alternatives as specified.  It will also assign the new split function.

The split function is called with two arguments, the argument passed to `show`/`outcome` and the split test object.  The
split function returns an array with two elements, the participant identifier (string or number) and the alternative
number (from 0 to n-1).

#### split(id, function, [title ...])

Returns a `SplitTest` using the specified split function and number of alternatives.  If the split test already exists,
modifies it to have at least as many alternatives as specified.  It will also assign the new split function, and set the
title of each alternative.

#### funnel(id)

Returns a `Funnel` without modifying it.

#### funnel(id, [step ...])

Creates and returns a `Funnel` with the specified set of steps.

#### rollout(id)

Returns a `RollOut` without modifying it.  If there is no such roll-out, creates a new one and sets the ratio of 0.

#### rollout(id, ratio)

Returns a `RollOut` with the specified ratio (number from 0 to 100) for the second alternative.  If the roll-out already
exists, modifies its ratio, otherwise creates a new roll-out.

#### rollout(id, function, ratio)

Returns a `RollOut` using the specified split function and ratio for the second alternative.  If the roll-out already
exists, modifies its ratio, otherwise creates a new roll-out.  It will also assign the new split function.

The split function is called with two arguments, the argument passed to `show` and the roll-out object.  The split
function returns `true` or `false`.

#### show(id, participant)

When used with a split test, returns the alternative number for the given participant and split test.  If the split test
doesn't exist, creates a new one with two alternatives.

When used with a roll-out, returns either `true` (rolled-out changes) or `false` for the given participant and feature.
If the roll-out doesn't exist, creates a new one with the ratio 0.

In both cases, the participant identifier can be a string or a number, and when using a split function, any object that
the function accepts.

#### outcome(id, participant, value)

When used with a split test, indicates conversion of the given participant and split test.  The value is optional, if
used, it may be a numeric value or a string.  If the split test doesn't exist, creates a new one with two alternatives.

When used with a funnel, indicates conversion of the given participant and split test.  The value is required and must
be the name of a step in the funnel.

The participant identifier can be a string or a number, and when using a split function (split test only), any object
that the function accepts.

#### activity(actor, verb, options)

Adds an activity to the stream.  The activity must have an actor and a verb.  Options may include the `object` on which
the action is performed, the `target` to which the object belong, and any number of `labels`.

#### for(participant)

Returns a `Participant` object for the given participant identifier.  This can be used as a short-cut for calling the
`show` and `outcome` methods.

#### connect(endpoint, interval)

Used to connect Vanity to a back-end and specify the refresh interval (omit to use the default value).


### SplitTest

#### show(participant)

See `show` method for the `Vanity` module.

#### outcome(participant, value)

See `outcome` method for the `Vanity` module.

#### alternativeFor(identifier)

Returns an alternative for the given participant.  The `show` method will pass the participant argument to the split
function which may (and the default split function does) call this method.  This method only accepts string or number.


### RollOut

#### show(participant)

See `show` method for the `Vanity` module.

#### featureFor(identifier)

Returns `true` or `false`.  The `show` method will pass the participant argument to the split function which may (and
the default split function does) call this method.  This method only accepts string or number.


### Funnel

#### outcome(participant, step)

See `outcome` method for the `Vanity` module.


### Participant

#### show(id)

See `show` method for the `Vanity` module.

#### outcome(id, step)

See `outcome` method for the `Vanity` module.

#### activity(verb, options)

Adds an activity to the stream.  If participant is an object, uses its properties as the actor; otherwise assumes the
participant is an identifier (string or number) and makes up a name based on that identifier.

Options may include the `object` on which the action is performed, the `target` to which the object belong, and any
number of `labels`.


