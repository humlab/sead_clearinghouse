# VISEAD ClearingHouse

A clearinghouse system for the SEAD database including script for reporting and manual imports.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

What things you need to install the software and how to install them
```
- Docker
```
### Installing

#### Setup development environment
Clone the project from source.
```
$ git clone https://github.com/humlab/sead_clearinghouse.git
```

#### Setup the clearinghouse database
Follow instructions in `sql/README`. `npm run build:clean-db` does a clean indtall.

#### Build Web Application
Compile and bundle the entire web application:
```
npm run build:release
```
Bundled deployment files are stored in `./dist` if build succeeds.

## Deployment

1. Copy `./dist` folder to target server.
2. Run `start_clearinghouse.bash --build`

## Built With

## Authors

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Hat tip to anyone whose code was used
* Inspiration
* etc
