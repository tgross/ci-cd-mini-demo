FROM python:3.6-alpine

# the Alpine image doesn't include sqlite3 by default
RUN apk --no-cache add sqlite

COPY /src /src
RUN pip install -r /src/requirements.txt
