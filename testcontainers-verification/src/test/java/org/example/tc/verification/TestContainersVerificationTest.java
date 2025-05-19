package org.example.tc.verification;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.DriverManager;
import java.sql.SQLException;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * Verify if TestContainers required setup works as expected.
 * The main purpose is to verify if TestContainers can find and use a suitable docker engine.
 */
class TestContainersVerificationTest {

    private static final int POSTGRES_MAJOR_VERSION = 16;
    private static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>(
            DockerImageName.parse("postgres:" + POSTGRES_MAJOR_VERSION + "-alpine")
                    .asCompatibleSubstituteFor("postgres")
    );


    @BeforeAll
    static void beforeAll() {
        postgres.start();
    }

    @AfterAll
    static void afterAll() {
        postgres.stop();
    }


    @Test
    void testcontainersVerification() throws SQLException {

        // Connect to TestContainers-managed PostgreSQL, retrieve its major version
        // and assert that it matches the expected value.

        try (Connection connection = DriverManager.getConnection(
                postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())) {

            DatabaseMetaData metaData = connection.getMetaData();
            int databaseMajorVersion = metaData.getDatabaseMajorVersion();
            assertEquals(POSTGRES_MAJOR_VERSION, databaseMajorVersion);
        }
    }
}