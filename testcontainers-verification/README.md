# TestContainers verification

Verifies if your environment can run [TestContainers](https://testcontainers.com) based tests.

This is mainly to see if TestContainers can find a suitable docker environment.

### Verification

If ...

```bash
mvn test
```

... executes without errors, then TestContainers can find a docker engine and can use it.


