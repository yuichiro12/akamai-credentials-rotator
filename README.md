# akamai-credentials-rotator
This docker image [rotates akamai api credentials](https://techdocs.akamai.com/iam-api/reference/rotate-credentials) storing credentials in Parameter Store.

## Usage

```shell
$ git clone git@github.com:yuichiro12/akamai-credentials-rotator.git
$ docker build . -t akamai-credentials-rotator
# requires AWS credentials to run locally
$ docker run --rm -it -v $HOME/.aws:/root/.aws akamai-credentials-rotator ./rotate.sh /path1/to/parameters /path2/to/parameters
```
