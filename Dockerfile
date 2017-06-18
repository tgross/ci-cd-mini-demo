FROM python:3.6-alpine

COPY /src /src
RUN pip install -r /src/requirements.txt
