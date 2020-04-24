import os

import requests
import sqlalchemy
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail
from sqlalchemy import MetaData, Table


def main(req):  # TODO: change to input params through req
    username = os.environ['PG_USER']
    password = os.environ['PG_PASS']
    db_name = os.environ['DB_NAME']
    slack_key = os.environ['SLACK_KEY']
    sendgrid_key = os.environ['SENDGRID_KEY']
    target_email = os.environ['TARGET_EMAIL']
    from_email = os.environ['FROM_EMAIL']
    in_cloud = 'IN_CLOUD' in os.environ

    print('starting')

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
            headers={'Authorization': f'Bearer {slack_key}'}
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

    if len(new_emojis) == 0 and len(emojis_to_update) == 0:
        return

    update_emoji_html = "\n\n".join([
        f'<div>{name} <a> src="{existing_emojis[name]}"/> -> <img src="{url}"/></div>'
        for name, url in emojis_to_update.items()
    ])
    new_emoji_html = "\n\n".join(
        [f'<div>{emoji["name"]} <img src="{emoji["img_url"]}"/></div>' for emoji in new_emojis]
    )

    email_body = f"""
    <p>Updated emojis:</p>
    
    {update_emoji_html}
    
    
    
    <p>New emojis:</p>

    {new_emoji_html}
    """

    message = Mail(
        from_email=from_email,
        to_emails=target_email,
        subject='New Emoji Alert',
        html_content=email_body,
    )

    sg = SendGridAPIClient(sendgrid_key)
    response = sg.send(message)
    print(response.status_code)
    print(response.body)
    print(response.headers)


if __name__ == '__main__':
    main(None)
