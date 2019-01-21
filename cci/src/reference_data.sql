
-- Reference data

-- Cloud Services Costs
insert into services_cost values ('DbSystem','CPU','ENTERPRISE_EDITION_EXTREME_PERFORMANCE', 'N', 'OCPU','hour','EUR', 2.188, 1.4587);
insert into services_cost values ('DbSystem','CPU','ENTERPRISE_EDITION_EXTREME_PERFORMANCE', 'Y', 'OCPU','hour','EUR', 0.252, 0.168);
insert into services_cost values ('DbSystem','Block Storage','', 'Y', 'GB','month','EUR', 0.0369, 0.0369);
insert into services_cost values ('DbSystem','Block Storage','', 'N', 'GB','month','EUR', 0.0369, 0.0369);

insert into services_cost values ('AutonomousDataWarehouse','CPU','', 'N', 'OCPU','hour','EUR', 2.188, 1.4587);
insert into services_cost values ('AutonomousDataWarehouse','CPU','', 'Y', 'OCPU','hour','EUR', 0.4201, 0.2801);
insert into services_cost values ('AutonomousDataWarehouse','Storage','', 'Y', 'TB','month','EUR', 192.7404, 128.4936);
insert into services_cost values ('AutonomousDataWarehouse','Storage','', 'N', 'TB','month','EUR', 192.7404, 128.4936);

insert into services_cost values ('Instance','CPU','VM.Standard2.1', 'N', 'OCPU','hour','EUR', 0.0554, 0.0554);
insert into services_cost values ('Instance','CPU','VM.Standard.E2.1', 'N', 'OCPU','hour','EUR', 0.02605, 0.02605);
insert into services_cost values ('Instance','CPU','VM.Standard2.2', 'N', 'OCPU','hour','EUR', 2 * 0.0554, 2 * 0.0554);

COMMIT;

