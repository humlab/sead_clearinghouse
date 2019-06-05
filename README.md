# VISEAD ClearingHouse

A clearinghouse system for the SEAD database including script for reporting and data imports.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites
What things you need to install the software and how to install them
```
- Docker
```
#### Setup development environment
Clone the project from source.
```bash
git clone https://github.com/humlab/sead_clearinghouse.git
```
Run webpack in development and watch mode (bundles source files to ./public)
```bash
npm run dev
```

#### Setup the clearinghouse database
Follow instructions in `sql/README`. `npm run build:clean-db` does a clean indtall.

## Build application
### Docker image (prefered)
Download latest [Dockerfile](https://github.com/humlab-sead/sead_clearinghouse/raw/master/Dockerfile) (into an empty folder) and build the image from the same folder.
```
wget https://github.com/humlab-sead/sead_clearinghouse/raw/master/Dockerfile
docker build --no-cache -t clearinghouse/app:latest .
```
### Bundled web from source
Compile and bundle the entire web application using `npm`:
```
npm install .
npm run build:release
```
Bundled files are stored in `./public` and is a ready to be deployed web (`./dist` is a compressed version).

## Deployment

### Docker image (preferred)
```bash
docker run --rm -d -t clearinghouse/app:latest --env-file .docker-env -p 8060:8060
```
### Bundled source files
1. Copy `./public` folder to target server.
2. Run `start_clearinghouse.bash --build`

## Built With

## Authors

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Hat tip to anyone whose code was used
* Inspiration
* etc
