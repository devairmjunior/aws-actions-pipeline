import pandas as pd
from faker import Faker
import random
import uuid
from datetime import datetime, timedelta

def generate_fake_data(num_rows=1000):
    fake = Faker()
    data = []

    for _ in range(num_rows):
        transaction_id = str(uuid.uuid4())
        user_id = random.randint(1000, 9999)
        user_name = fake.name()
        email = fake.email()
        transaction_date = fake.date_time_between(start_date="-1y", end_date="now")
        transaction_amount = round(random.uniform(10.0, 1000.0), 2)
        payment_method = random.choice(["credit_card", "paypal", "bank_transfer", "crypto"])
        product_id = random.randint(100, 999)
        product_name = fake.word()
        country = fake.country()
        
        # Governança: Campos de auditoria
        created_at = datetime.now() - timedelta(days=random.randint(0, 365))
        updated_at = created_at + timedelta(days=random.randint(0, 30))
        is_active = random.choice([True, False])

        data.append({
            "transaction_id": transaction_id,
            "user_id": user_id,
            "user_name": user_name,
            "email": email,
            "transaction_date": transaction_date,
            "transaction_amount": transaction_amount,
            "payment_method": payment_method,
            "product_id": product_id,
            "product_name": product_name,
            "country": country,
            "created_at": created_at,
            "updated_at": updated_at,
            "is_active": is_active,
        })

    return pd.DataFrame(data)

# Gerar o DataFrame
dataframe = generate_fake_data(1000)

# Salvar o DataFrame em formato CSV para ingestão
dataframe.to_csv("transactions.csv", index=False)

print("DataFrame gerado e salvo como 'transactions.csv'. Exemplo de dados:")
print(dataframe.head())