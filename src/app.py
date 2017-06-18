from flask import Flask, request, redirect, url_for
import sqlite3 as sql
application = Flask(__name__)


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
        con = sql.connect("database.db")
        cur = con.cursor()
        cur.execute("INSERT INTO users (username) VALUES (?)", (username, ))
        con.commit()
        con.close()
        return redirect(url_for('success'))
    except:
        return redirect(url_for('fail'))


if __name__ == "__main__":
    application.run(host='0.0.0.0')
