
import mysql.connector
from connection import get_connection

def cadastrar_produto(usuario):
    if usuario['cargo'] not in ['gerente', 'CEO']:
        print("⚠️ Você não tem permissão para cadastrar produtos.")
        return

    descricao = input("Descrição do produto: ").strip()
    quantidade = int(input("Quantidade: "))
    valor = float(input("Valor (R$): "))

    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("""
            INSERT INTO produto (descricao, quantidade, valor)
            VALUES (%s, %s, %s)
        """, (descricao, quantidade, valor))
        conn.commit()
        print("✅ Produto cadastrado com sucesso!")
    except mysql.connector.Error as err:
        print(f"Erro ao cadastrar produto: {err}")
    finally:
        cursor.close()
        conn.close()

def listar_clientes():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute("SELECT * FROM cliente")
        clientes = cursor.fetchall()

        if not clientes:
            print("Nenhum cliente encontrado.")
        else:
            print("\n👤 Lista de Clientes:")
            for cli in clientes:
                print(f"ID: {cli['id']} | Nome: {cli['nome']} | Sexo: {cli['sexo']} | Idade: {cli['idade']} | Nascimento: {cli['nascimento']}")
    except Exception as e:
        print(f"Erro ao buscar clientes: {e}")
    finally:
        cursor.close()
        conn.close()


def listar_produtos():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute("SELECT * FROM produto")
        produtos = cursor.fetchall()

        if not produtos:
            print("Nenhum produto cadastrado.")
        else:
            print("\n📦 Lista de Produtos:")
            for prod in produtos:
                print(f"ID: {prod['id']} | Descrição: {prod['descricao']} | Quantidade: {prod['quantidade']} | Valor: R$ {prod['valor']:.2f}")

    except Exception as e:
        print(f"Erro ao buscar produtos: {e}")
    finally:
        cursor.close()
        conn.close()