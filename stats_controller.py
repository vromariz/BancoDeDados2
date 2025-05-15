import mysql.connector
from connection import get_connection

def mostrar_estatisticas():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    print("\n📊 Estatísticas de Venda:")

    try:
        # Produto mais vendido
        cursor.execute("""
            SELECT p.descricao, COUNT(v.id) AS total_vendas
            FROM venda v
            JOIN produto p ON v.id_produto = p.id
            GROUP BY p.id
            ORDER BY total_vendas DESC
            LIMIT 1
        """)
        mais_vendido = cursor.fetchone()
        if mais_vendido:
            print(f"🔝 Produto mais vendido: {mais_vendido['descricao']} ({mais_vendido['total_vendas']} vendas)")

        # Produto menos vendido
        cursor.execute("""
            SELECT p.descricao, COUNT(v.id) AS total_vendas
            FROM venda v
            RIGHT JOIN produto p ON v.id_produto = p.id
            GROUP BY p.id
            ORDER BY total_vendas ASC
            LIMIT 1
        """)
        menos_vendido = cursor.fetchone()
        if menos_vendido:
            print(f"📉 Produto menos vendido: {menos_vendido['descricao']} ({menos_vendido['total_vendas']} vendas)")

    except mysql.connector.Error as err:
        print(f"Erro ao consultar estatísticas: {err}")
    finally:
        cursor.close()
        conn.close()