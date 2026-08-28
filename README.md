# Trasia

A Flutter-based travel and mobility application for Malaysia that brings together public transit planning, ride pooling, trip discovery, rewards, and account management in one platform.

## Features

- Public transit route planning for Rapid KL rail, buses, MRT feeder services, and KTMB
- Hub-based car-pooling with driver tracking, ride queues, and QR check-ins
- Travel planning with attraction discovery and trip cost estimates
- Rewards, voucher redemption, check-in memories, and trip history
- Digital wallet top-ups through Stripe PaymentSheet in test mode
- Secure authentication and profile management powered by Supabase
- Firebase Cloud Messaging push notifications
- Admin tools for managing users, drivers, vouchers, and analytics
- Government and open-data references from data.gov.my, OpenDOSM, MYSA, and the World Bank

## Installation

```bash
# clone the repo
git clone https://github.com/jeeshen/Trasia.git

# navigate to project directory
cd Trasia

# install Flutter dependencies
flutter pub get

# create the environment configuration file
cp .env.example .env

# run the application
flutter run
```
