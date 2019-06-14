<?php

use PHPUnit\Framework\TestCase;

final class UtilityTest extends TestCase {

    public function testCanBeUsedAsString(): void
    {
        $this->assertEquals(
            'user@example.com',
            Email::fromString('user@example.com')
        );
    }

    public function testCanConvertToCamelCase(): void
    {
        $this->assertEquals( \InfraStructure\Utility\toCamelCase("can_convert_to_camel_case", false, false), "canConvertToCamelCase");
        $this->assertEquals( \InfraStructure\Utility\toCamelCase("can_convert_to_camel_case", true, false), "CanConvertToCamelCase");
        $this->assertEquals( \InfraStructure\Utility\toCamelCase("can_convert_to_camel_case", true, true), "Can Convert To Camel Case");
    }
}
?>