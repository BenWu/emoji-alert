import os

import requests
import sqlalchemy
from sqlalchemy import MetaData, Table


def main(req):
    username = os.environ['PG_USER']
    password = os.environ['PG_PASS']
    db_name = os.environ['DB_NAME']
    api_key = os.environ['API_KEY']
    in_cloud = 'IN_CLOUD' in os.environ

    if not in_cloud:
        connection_string = (f'postgresql+psycopg2://{username}:{password}'
                             f'@127.0.0.1:5432/{db_name}?sslmode=disable')
        db = sqlalchemy.create_engine(connection_string)
    else:
        connection_name = os.environ['CONNECTION_NAME']

        db = sqlalchemy.create_engine(
            sqlalchemy.engine.url.URL(
                drivername='postgresql+psycopg2',
                username=username,
                password=password,
                database=db_name,
                host=f'/cloudsql/{connection_name}',
            )
        )

    with db.connect() as conn:
        emoji_table = Table('emojis', MetaData(), autoload=True, autoload_with=db)

        results = conn.execute(emoji_table.select()).fetchall()
        existing_emojis = {result[0]: result[1] for result in results}

        response = requests.get(
            'https://slack.com/api/emoji.list',
            headers={'Authorization': f'Bearer {api_key}'}
        )
        response.raise_for_status()
        emojis = {
            name: url
            for name, url in response.json()['emoji'].items()
        }

        emojis_to_update = {
            name: url for name, url
            in emojis.items() if name in existing_emojis
                                 and existing_emojis[name] != url
        }
        for name, url in emojis_to_update.items():
            conn.execute(
                emoji_table.update().where(emoji_table.c.name == name).values(img_url=url)
            )

        new_emojis = [
            {'name': name, 'img_url': url} for name, url
            in emojis.items() if name not in existing_emojis
        ]
        if len(new_emojis) > 0:
            conn.execute(emoji_table.insert(values=new_emojis))

        print(new_emojis)


if __name__ == '__main__':
    main(None)
