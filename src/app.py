import os
import sqlite3

from flask import Flask, request, redirect, url_for
import pymysql

application = Flask(__name__)

application.config['db_host'] = os.environ.get('DB_HOST', '')
application.config['db_user'] = os.environ.get('DB_USER', 'user')
application.config['db_passwd'] = os.environ.get('DB_PASSWD', 'passwd')

@application.route('/')
def hello_world():
    return 'Hello, World!'


@application.route('/success')
def success():
    return 'Success!'


@application.route('/fail')
def fail():
    return 'Something went wrong.'


@application.route('/create', methods=['POST'])
def create():
    try:
        username = request.form['username']

        # realistically this is a terrible idea because we're likely
        # to have DB-specific queries that won't be compatible between
        # sqlite and MySQL
        if not application.config.get('db_host'):
            con = sql.connect('database.db')
        else:
            con = pymysql.connect(host=application.config['db_host'],
                                  user=application.config['db_user'],
                                  password=application.config['db_passwd'],
                                  db='db',
                                  charset='utf8mb4',
                                  cursorclass=pymysql.cursors.DictCursor)
        cur = con.cursor()
        cur.execute("INSERT INTO users (username) VALUES (?)", (username, ))
        con.commit()
        con.close()
        return redirect(url_for('success'))
    except:
        return redirect(url_for('fail'))


if __name__ == "__main__":
    application.run(host='0.0.0.0')
