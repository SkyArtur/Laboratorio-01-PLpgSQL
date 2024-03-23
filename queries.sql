/*---------------------------------------------------------------------------------------------------------------------
                                    EXCLUSÕES
---------------------------------------------------------------------------------------------------------------------*/

DROP TABLE vendas;
DROP TABLE produtos;
DROP TABLE estoque;

/*---------------------------------------------------------------------------------------------------------------------
                                    TABELAS
---------------------------------------------------------------------------------------------------------------------*/

CREATE TABLE estoque (
    produto VARCHAR(255) PRIMARY KEY,
    quantidade INTEGER,
    custo NUMERIC(11, 2),
    lucro NUMERIC,
    data DATE
);

CREATE TABLE produtos (
    nome VARCHAR(255) PRIMARY KEY,
    preco NUMERIC(11, 2),
    FOREIGN KEY (nome)
        REFERENCES estoque(produto)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE vendas (
    produto VARCHAR(255),
    data DATE DEFAULT CURRENT_DATE,
    quantidade INTEGER,
    valor NUMERIC(11, 2),
    ref VARCHAR(255),
    FOREIGN KEY (ref)
        REFERENCES estoque(produto)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO TRIGGER criar_produto
---------------------------------------------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION criar_produto ()
    RETURNS TRIGGER AS $$
        BEGIN
            INSERT INTO produtos (nome, preco)
                VALUES (NEW.produto, calcular_preco(NEW.quantidade, NEW.custo, NEW.lucro));
            RETURN NEW;
        END;
    $$ LANGUAGE plpgsql;

/*---------------------------------------------------------------------------------------------------------------------
                                    TRIGGER trigger_criar_produto
---------------------------------------------------------------------------------------------------------------------*/

CREATE TRIGGER trigger_create_produto
    AFTER INSERT ON estoque
    FOR EACH ROW
    EXECUTE FUNCTION criar_produto();

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO TRIGGER atualizar_quantidade_em_estoque
---------------------------------------------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION atualizar_quantidade_em_estoque()
    RETURNS TRIGGER AS $$
        BEGIN
            UPDATE estoque
                SET quantidade = quantidade - NEW.quantidade
                WHERE produto = NEW.ref;
            RETURN NEW;
        END;
    $$ LANGUAGE plpgsql;

/*---------------------------------------------------------------------------------------------------------------------
                                    TRIGGER trigger_quantidade_em_estoque
---------------------------------------------------------------------------------------------------------------------*/

CREATE TRIGGER trigger_quantidade_em_estoque
    AFTER INSERT ON vendas
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_quantidade_em_estoque();

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO calcular_preco
---------------------------------------------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION calcular_preco(quantidade INTEGER, custo NUMERIC, lucro NUMERIC)
    RETURNS NUMERIC AS $$
        DECLARE
            preco NUMERIC;
        BEGIN
            preco :=  custo / quantidade;
            preco := preco + (preco * (lucro / 100));
            RETURN ROUND(preco, 2);
        END;
    $$ LANGUAGE plpgsql;

/*########           TESTES           ########*/
SELECT * FROM calcular_preco(100, 100, 50);

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO calcular_valor_da_venda
---------------------------------------------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION calcular_valor_da_venda(preco NUMERIC, quantidade INTEGER, desconto NUMERIC DEFAULT NULL)
    RETURNS NUMERIC AS $$
        DECLARE
            valor NUMERIC;
        BEGIN
            IF desconto IS NOT NULL
                THEN
                valor := preco - (preco * (desconto / 100));
                valor := valor * quantidade;
            ELSE
                valor := preco * quantidade;
            END IF;
            RETURN ROUND(valor, 2);
        END;
    $$ LANGUAGE plpgsql;

/*########           TESTES           ########*/
SELECT * FROM calcular_valor_da_venda(1.5, 2);
/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO registrar_produto_no_estoque
---------------------------------------------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION registrar_produto_no_estoque(_produto VARCHAR, _quantidade INTEGER, _custo NUMERIC, _lucro NUMERIC, _data DATE)
    RETURNS BOOLEAN AS $$
        BEGIN
            INSERT INTO estoque (produto, quantidade, custo, lucro, data)
                VALUES (_produto, _quantidade, _custo, _lucro, _data);
            RETURN TRUE;
        EXCEPTION
            WHEN others
                THEN
                    RETURN FALSE;
        END;
    $$ LANGUAGE plpgsql;

/*########           TESTES           ########*/
SELECT * FROM registrar_produto_no_estoque('abacate', 300, 455, 22, '2024-03-21');
SELECT * FROM registrar_produto_no_estoque('banana', 250, 265, 25, '2024-03-21');
SELECT * FROM registrar_produto_no_estoque('morango', 650, 832, 45, '2024-03-21');
SELECT * FROM registrar_produto_no_estoque('laranja', 250, 440, 15, '2024-03-21');
SELECT * FROM registrar_produto_no_estoque('tomate', 500, 732, 25, '2024-03-21');

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO registrar_venda
---------------------------------------------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION registrar_venda(_produto VARCHAR, _quantidade INTEGER, desconto NUMERIC DEFAULT NULL)
    RETURNS BOOLEAN AS $$
        DECLARE
            existe BOOLEAN;
            _preco NUMERIC;
        BEGIN
            SELECT p.preco, TRUE INTO _preco, existe
                FROM produtos p
                JOIN estoque e ON e.produto = p.nome
                WHERE e.produto = _produto AND e.quantidade >= _quantidade;
            IF existe
                THEN
                    INSERT INTO vendas (produto, quantidade, valor, ref)
                        VALUES (
                            _produto,
                            _quantidade,
                            calcular_valor_da_venda(_preco, _quantidade, desconto),
                            _produto
                        );
                    RETURN TRUE;
            END IF;
            RETURN FALSE;
        END;
    $$ LANGUAGE plpgsql;

/*########           TESTES           ########*/
SELECT * FROM registrar_venda('morango', 20);
SELECT * FROM registrar_venda('morango', 12);
SELECT * FROM registrar_venda('morango', 8);
SELECT * FROM registrar_venda('morango', 8, 5);

SELECT * FROM registrar_venda('banana', 6);
SELECT * FROM registrar_venda('banana', 18, 7);

SELECT * FROM registrar_venda('abacate', 8);
SELECT * FROM registrar_venda('abacate', 6);
SELECT * FROM registrar_venda('abacate', 4);
SELECT * FROM registrar_venda('abacate', 3);

SELECT p.nome as "produto", v.data, v.quantidade, v.valor
    FROM vendas as v
    JOIN produtos as p
    ON v.produto = p.nome
WHERE v.produto = 'laranja';

SELECT e.produto, e.quantidade, e.custo, e.lucro, p.preco
    FROM estoque as e
    JOIN produtos as p
    ON e.produto = p.nome
WHERE produto = 'laranja';

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO selecionar_produto_em_estoque
---------------------------------------------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION selecionar_produto_em_estoque(_produto VARCHAR DEFAULT NULL)
    RETURNS TABLE (produto VARCHAR, quantidade INTEGER, custo NUMERIC, lucro NUMERIC, preco NUMERIC) AS $$
        BEGIN
            IF _produto IS NOT NULL
                THEN
                    RETURN QUERY
                        SELECT e.produto, e.quantidade, e.custo, e.lucro, p.preco
                            FROM estoque e
                            JOIN produtos p
                            ON e.produto = p.nome
                        WHERE e.produto = _produto;
            ELSE
                RETURN QUERY
                    SELECT e.produto, e.quantidade, e.custo, e.lucro, p.preco
                        FROM estoque e
                        JOIN produtos p
                        ON e.produto = p.nome
                    ORDER BY e.produto;
            END IF;
        END;
    $$ LANGUAGE plpgsql;

/*########           TESTES           ########*/
SELECT * FROM selecionar_produto_em_estoque();

SELECT * FROM selecionar_produto_em_estoque('laranja');

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO selecionar_vendas
---------------------------------------------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION selecionar_vendas(_produto VARCHAR DEFAULT NULL)
    RETURNS TABLE (produto VARCHAR, data DATE, quantidade INTEGER, valor NUMERIC) AS $$
        BEGIN
            IF _produto IS NOT NULL
                THEN
                    RETURN QUERY
                        SELECT v.produto, v.data, v.quantidade, v.valor
                            FROM vendas v
                        WHERE v.ref = _produto
                            ORDER BY v.data DESC;
            ELSE
                RETURN QUERY
                    SELECT v.produto, v.data, v.quantidade, v.valor
                        FROM vendas v
                        ORDER BY v.produto, v.data DESC;
            END IF;
        END;
    $$ LANGUAGE plpgsql;

/*########           TESTES           ########*/
SELECT * FROM selecionar_vendas('laranja');


/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO selecionar_produto_para_venda
---------------------------------------------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION selecionar_produto_para_venda(_produto VARCHAR DEFAULT NULL)
    RETURNS TABLE (produto VARCHAR, preco NUMERIC) AS $$
        BEGIN
            IF _produto IS NOT NULL
                THEN
                    RETURN QUERY
                    SELECT p.nome, p.preco
                        FROM produtos p
                    WHERE p.nome = _produto ORDER BY p.nome;
            ELSE
                RETURN QUERY
                    SELECT p.nome, p.preco FROM produtos p ORDER BY p.nome;
            END IF;
        END;
    $$ LANGUAGE plpgsql;

/*########           TESTES           ########*/
SELECT * FROM selecionar_produto_para_venda();

SELECT * FROM selecionar_produto_para_venda('abacate');

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO atualizar_dados_estoque_e_produto
---------------------------------------------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION atualizar_dados_estoque_e_produto(_produto VARCHAR, _quantidade INTEGER DEFAULT NULL, _custo NUMERIC DEFAULT NULL, _lucro NUMERIC DEFAULT NULL)
    RETURNS TABLE (prod VARCHAR, qtd INTEGER, cst NUMERIC, lcr NUMERIC, prc NUMERIC) AS $$
        DECLARE
            custo NUMERIC;
            lucro NUMERIC;
            quantidade INTEGER;
        BEGIN
            IF _quantidade IS NOT NULL
                THEN
                    UPDATE estoque
                        SET quantidade = _quantidade
                    WHERE produto=_produto;
            END IF;
            IF _custo IS NOT NULL
                THEN
                    SELECT e.quantidade, e.lucro INTO quantidade, lucro
                        FROM estoque e WHERE e.produto = _produto;
                    UPDATE estoque
                        SET custo = _custo
                    WHERE produto = _produto;
                    UPDATE produtos
                        SET preco = calcular_preco(quantidade, _custo, lucro)
                    WHERE nome = _produto;
            END IF;
            IF _lucro IS NOT NULL
                THEN
                    SELECT e.quantidade, e.custo INTO quantidade, custo
                        FROM estoque e WHERE e.produto = _produto;
                    UPDATE estoque
                        SET lucro = _lucro
                    WHERE produto = _produto;
                    UPDATE produtos
                        SET preco = calcular_preco(quantidade, custo, _lucro)
                    WHERE nome = _produto;
            END IF;
            RETURN QUERY
                SELECT * FROM selecionar_produto_em_estoque(_produto) as s;
        END;
    $$ LANGUAGE plpgsql;

/*########           TESTES           ########*/
SELECT * FROM selecionar_produto_em_estoque('abacate');

SELECT * FROM atualizar_dados_estoque_e_produto('abacate', 100, 100, 5 );

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO deletar_produto
---------------------------------------------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION deletar_produto(_product VARCHAR)
    RETURNS BOOLEAN AS $$
        DECLARE
            existe BOOLEAN;
        BEGIN
            SELECT TRUE INTO existe FROM estoque WHERE produto = _product;
            IF existe
                THEN
                    DELETE FROM estoque WHERE produto = _product;
                    RETURN TRUE;
            ELSE
                RETURN FALSE;
            END IF;
        END;
    $$ LANGUAGE plpgsql;

SELECT * FROM selecionar_produto_em_estoque();
SELECT * FROM selecionar_produto_para_venda();
SELECT * FROM selecionar_vendas();
SELECT * FROM deletar_produto('morango');

SELECT * FROM vendas;
