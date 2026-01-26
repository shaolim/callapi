# The Challenge

At Tripla, we use a dynamic pricing model for hotel rooms. Instead of static, unchanging rates, our model uses a real-time algorithm to adjust prices based on market demand and other data signals. This helps us maximize both revenue and occupancy.

Our Data and AI team built a powerful model to handle this, but its inference process is computationally expensive to run. To make this product more cost-effective, we analyzed the model's output and found that a calculated room rate remains effective for up to 5 minutes.

This insight presents a great optimization opportunity, and that's where you come in.

## Your Mission

Your mission is to build an efficient service that acts as an intermediary to our dynamic pricing model. This service will be responsible for providing rates to our users while respecting the operational constraints of the expensive model behind it.

You will start with a minimal Ruby on Rails application scaffold that currently returns a static price. You'll need to bring it to life.

## Core Requirements

1. Integrate the Pricing Model: Modify the provided service to call the external dynamic pricing API to get the latest rates. The model is available as a Docker image: [tripladev/rate-api](https://hub.docker.com/r/tripladev/rate-api).

2. Ensure Rate Validity: A rate fetched from the pricing model is considered valid for 5 minutes. Your service must ensure that any rate it provides for a given set of parameters (`period`, `hotel`, `room`) is no older than this 5-minute window.

3. Honor API Usage Limits: The model's API token is limited. Your solution must be able to handle at least 10,000 requests per day from our users while using a single API token for the pricing model.

## How We'll Evaluate Your Work

This isn't just about getting the right answer. We're excited to see how you approach the problem. Treat this as you would a production-ready feature.

- We'll be looking for clean, well-structured, and testable code. Feel free to add dependencies or refactor the existing scaffold as you see fit.
- How do you decide on your approach to meeting the performance and cost requirements? Documenting your thought process is a great way to share this.
- A reliable service anticipates failure. How does your service behave if the pricing model is slow, or returns an error? Providing descriptive error messages to the end-user is a key part of a robust API.
- We want to see how you work around constraints and navigate an existing codebase to deliver a solution.
