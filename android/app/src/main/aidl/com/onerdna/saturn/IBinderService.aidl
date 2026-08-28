package com.onerdna.saturn;

interface IBinderService {
    String runCommand(in String command);
    void destroy();
}
